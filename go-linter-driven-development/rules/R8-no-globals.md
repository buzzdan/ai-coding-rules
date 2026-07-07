# R8 — No Globals / Dependency Rejection

## Principle

Dependencies are passed down from the caller, never reached sideways: no
package-level mutable state, no `init()` writing state, no singletons fetched from
inside business logic, no `context.Background()` in library code — `ctx` flows from
caller to callee. Globals are acceptable only at entry points (`main`, handler
setup, application wiring), where they are read once and injected downward.

## Why

A global is a hidden parameter of every function that touches it. Hidden parameters
make code untestable except by mutating shared state — which forbids parallel tests,
lets state leak between tests, and hides from the reader what a function actually
needs. `env.Configs.X` reached from deep inside a publisher couples every caller to
one config struct and makes swapping the value per-test or per-environment
impossible without global writes. `context.Background()` deep in a call chain is the
same sin in context form: it severs cancellation, timeouts, and tracing from the
request that is actually running. Passing dependencies down turns each type into an
island of clean code: constructor-injected (`R2-self-validating-types.md`), fully
testable with fake data, parallel-safe. Not every global is a defect: loggers
designed to be global (`slog`, `zerolog`), constants, and `var Err... = errors.New`
sentinels are fine — the target is mutable state and configuration reached sideways.

## Canonical example

Real refactoring — `env.Configs.NATsAddress` was read in 12 places deep in the
codebase.

### Before — sideways access

```go
package messaging

func PublishEvent(event Event) error {
    conn, err := nats.Connect(env.Configs.NATsAddress) // global reached from a leaf
    if err != nil {
        return fmt.Errorf("connect failed: %w", err)
    }
    defer conn.Close()
    // ...
}

// the test must mutate shared state — and cannot run in parallel
func TestPublishEvent(t *testing.T) {
    env.Configs.NATsAddress = "nats://test:4222" // leaks into every other test
    // ...
}
```

### After — dependency rejected upward, injected at the edge

```go
package messaging

type NATSClient struct {
    natsAddress string // injected, not global
}

func NewNATSClient(natsAddress string) *NATSClient {
    return &NATSClient{natsAddress: natsAddress}
}

func (c *NATSClient) PublishEvent(event Event) error {
    conn, err := nats.Connect(c.natsAddress)
    // ...
}

// package api — the global is read ONLY at the entry point
func SetupOrderHandler() *OrderHandler {
    natsClient := NewNATSClient(env.Configs.NATsAddress)
    orderService := NewOrderService(env.Configs.DBHost, natsClient)
    return &OrderHandler{orderService: orderService}
}
```

The test constructs a client against a local test NATS server — no global writes,
`t.Parallel()` works. The refactoring is incremental: one clean island at a time,
pushing the global up one level per iteration, from 20 scattered accesses down to 2
at the entry points. Full worked case — the dependency map, the island-by-island
progression, and the test payoff: `../examples/dependency-rejection.md`.

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
- **`ctx` flows down.** Every function doing I/O takes `ctx context.Context` from
  its caller. `context.Background()` belongs in `main`/`TestMain`/tests — never in
  library code; a library that manufactures its own root context has silently opted
  out of cancellation.
- **`init()` computes nothing observable.** An `init()` that writes package state is
  a hidden constructor with no error path and no injection point — replace it with
  an explicit constructor called from the edge.
- **Singletons are wiring, not access.** A `sync.Once`-guarded package instance
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
- **Replace `init()` with a constructor**: delete the `init()`, expose
  `NewX(...) (X, error)`, call it from the wiring code.
- **Thread `ctx`**: add `ctx context.Context` as the first parameter down the chain;
  delete `context.Background()` from library code.
- Multi-rule sequencing with extraction/storifying:
  `../skills/refactoring/reference.md`.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Does any package declare mutable state at package level?**
   Detection: `grep -rn '^var ' --include='*.go' . | grep -v _test.go` — then
   exclude const-like declarations (`var Err... = errors.New(...)` sentinels,
   compile-time interface checks `var _ I = ...`).
   Violation: a package-level `var` that is written after initialization or holds
   configuration/state — reject it into a constructor-injected field.

2. **Does any `init()` write state?**
   Detection: `grep -rn 'func init()' --include='*.go' .` — read each body for
   assignments to package-level variables or registrations with side effects.
   Violation: `init()` mutating package state — replace with an explicit
   constructor called at the edge.

3. **Does library code manufacture its own context?**
   Detection: `grep -rn 'context.Background()\|context.TODO()' --include='*.go' . | grep -v _test.go | grep -v 'cmd/\|main.go'`
   Violation: any hit outside `main`/wiring — the function must take `ctx` from its
   caller.

4. **Is a singleton reached sideways?**
   Detection: `grep -rn 'sync.Once' --include='*.go' .` — check whether the guarded
   instance is a package-level var returned by a getter that business logic calls.
   Violation: `GetX()`-style access from inside logic — construct at the edge, pass
   down.

5. **Does deep code read a global config?**
   Detection: `grep -rn 'env\.Configs\|os.Getenv' --include='*.go' . | grep -v _test.go | grep -v 'cmd/\|main.go\|setup'`
   Violation: config reads outside entry-point wiring — each is a dependency to
   reject upward (`../examples/dependency-rejection.md`).

6. **Do tests mutate globals to run?**
   Detection: `grep -rn 'env.Configs.* =' --include='*_test.go' .`
   Violation: a test writing shared state to inject a value — the production code
   under test has a hidden dependency; fix the production code, not the test.
