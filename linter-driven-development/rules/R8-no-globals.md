# R8 — No Globals / Dependency Rejection

## Principle

Dependencies are passed down from the caller, never reached sideways: no
package-level mutable state, no import-time initialization writing state, no
singletons fetched from inside business logic, no library code that manufactures its
own root cancellation — cancellation flows from caller to callee. Globals are
acceptable only at entry points (`main`, handler setup, application wiring), where
they are read once and injected downward.

## Why

A global is a hidden parameter of every function that touches it. Hidden parameters
make code untestable except by mutating shared state — which forbids parallel tests,
lets state leak between tests, and hides from the reader what a function actually
needs. `env.Configs.X` reached from deep inside a publisher couples every caller to
one config object and makes swapping the value per-test or per-environment
impossible without global writes. A root cancellation context manufactured deep in a
call chain is the same sin in another form: it severs cancellation, timeouts, and
tracing from the request that is actually running. Passing dependencies down turns
each type into an island of clean code: constructor-injected (`R2-self-validating-types.md`), fully
testable with fake data, parallel-safe. Not every global is a defect: loggers
designed to be global, constants, and error sentinels are fine — the target is
mutable state and configuration reached sideways.

## Canonical example

Real refactoring — a global configuration value, the message broker's address, was
read in 12 places deep in the codebase.

### Before — sideways access

```text
# messaging module
publishEvent(event):
    conn = broker.connect(env.Configs.BrokerAddress)   # global reached from a leaf
    ...

# the test must mutate shared state — and cannot run in parallel
testPublishEvent():
    env.Configs.BrokerAddress = "broker://test:4222"   # leaks into every other test
    ...
```

### After — dependency rejected upward, injected at the edge

```text
# messaging module
BrokerClient
    address                  # injected, not global
newBrokerClient(address):
    return BrokerClient(address)
BrokerClient.publishEvent(event):
    conn = broker.connect(self.address)
    ...

# api module — the global is read ONLY at the entry point
setupOrderHandler():
    client = newBrokerClient(env.Configs.BrokerAddress)
    orders = newOrderService(env.Configs.DBHost, client)
    return OrderHandler(orders)
```

The test constructs a client against a local test broker — no global writes, tests
run in parallel. The refactoring is incremental: one clean island at a time, pushing
the global up one level per iteration, from 20 scattered accesses down to 2 at the
entry points.

## Design guidance

- **Reject the dependency upward.** A function that needs a value takes it — as a
  constructor argument on its type, or a parameter. The caller then faces the same
  choice, and the requirement bubbles up until it reaches an entry point that
  legitimately owns configuration.
- **Work bottom-up, one island at a time.** Start at the deepest usage (furthest
  from `main`), extract a clean constructor-injected type, and stop the iteration
  there — each step is a working, deployable state. Don't attempt a big-bang purge.
- **Pragmatic endpoint.** Globals at `main()`, handler setup, and top-level
  factories are acceptable; globals in business logic, data access, and library
  code are not. The goal is not zero globals — it is globals only where wiring
  happens.
- **Cancellation flows down.** Every function doing I/O takes the caller's
  cancellation context. A root context belongs in entry points and tests — never in
  library code; a library that manufactures its own root context has silently opted
  out of cancellation.
- **Import-time initialization computes nothing observable.** Initialization code
  that writes package state when the module loads is a hidden constructor with no
  error path and no injection point — replace it with an explicit constructor called
  from the edge.
- **Singletons are wiring, not access.** A lazily initialized package instance
  reached from business logic is a global with extra steps; construct once at the
  edge and pass it down.
- Constructor injection and validation of the injected deps:
  `R2-self-validating-types.md`. Forward design of the extracted types:
  @code-designing.

## Fix pattern

- **Extract Clean Island**: at the deepest global usage, create a type whose
  constructor takes the value (`NewNATSClient(addr)`); move the logic onto it.
- **Push the Global Up One Level**: each caller now constructs or receives the
  island; repeat per level until the global is read only at entry points. Full
  progression: `../examples/dependency-rejection.md`.
- **Replace Import-Time Initialization with a Constructor**: delete the load-time
  initializer, expose `NewX(...)` returning the value or an error, call it from the
  wiring code.
- **Pass Cancellation Down**: add the cancellation context as a parameter down the
  chain; delete every manufactured root context from library code.
- Multi-rule sequencing with extraction/storifying:
  `../skills/refactoring/reference.md`.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

Build each search over the language's source files (`detected-language source`), excluding test
files; "entry point" means the main function, application wiring and handler setup.

1. **Does any package declare mutable state at package level?**
   Detection: search the non-test source files for module-level or package-level
   variable declarations (a `var` at column 0, an assignment at module top level, a
   static mutable field) — then exclude const-like declarations (error sentinels,
   frozen constants, compile-time interface checks).
   Violation: a package-level variable that is written after initialization or holds
   configuration/state — reject it into a constructor-injected field.

2. **Does any import-time initializer write state?**
   Detection: search for the language's load-time hooks (an `init` function, a
   module body that runs code on import, a static initializer block) — read each for
   assignments to package-level variables or registrations with side effects.
   Violation: import-time code mutating package state — replace with an explicit
   constructor called at the edge.

3. **Does library code manufacture its own cancellation root?**
   Detection: search the non-test source files outside the entry points for the
   language's root-context or fresh-event-loop constructors (a background context, a
   new event loop, a cancellation source created deep in a call chain).
   Violation: any hit outside the entry points — the function must take the
   cancellation signal from its caller.

4. **Is a singleton reached sideways?**
   Detection: search for the language's once-only initialization idiom (a once
   guard, a lazily created module-level instance, a memoized getter) — check whether
   the guarded instance is a package-level variable returned by a getter that
   business logic calls.
   Violation: `getX()`-style access from inside logic — construct at the edge, pass
   down.

5. **Does deep code read a global config?**
   Detection: search the non-test source files outside the entry points for reads of
   the configuration object and of environment variables (`env.Configs`,
   `os.Getenv`, `os.environ`, `process.env`).
   Violation: config reads outside entry-point wiring — each is a dependency to
   reject upward.

6. **Do tests mutate globals to run?**
   Detection: search the test files for assignments to the configuration object or
   to package-level variables (`env.Configs.X =`, a monkeypatch of a module
   attribute).
   Violation: a test writing shared state to inject a value — the production code
   under test has a hidden dependency; fix the production code, not the test.
