# R8 — No Globals / Dependency Rejection

## Principle

Dependencies are passed down from the caller, never reached sideways: no
package-level mutable state, no import-time initialization writing state, no
singletons fetched from inside business logic, no library code that manufactures its
own root cancellation — cancellation flows from caller to callee. Globals are
acceptable only at the composition root — the program's entry point, handler setup,
application wiring — where they are read once and injected downward.

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

Real refactoring shape — `CONFIG.nats_address` was read in 12 places deep in the
codebase.

### Before — sideways access

```python
# messaging/publish.py
from app.env import CONFIG                      # a module-level config object, built at import


def publish_event(event: Event) -> None:
    conn = nats.connect(CONFIG.nats_address)    # global reached from a leaf
    try:
        ...
    finally:
        conn.close()


# test_publish.py — the test must mutate shared state, and cannot run in parallel
def test_publish_event(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(env, "CONFIG", Config(nats_address="nats://test:4222"))   # leaks into every other test
    ...
```

### After — dependency rejected upward, injected at the edge

```python
# messaging/publish.py
class NatsClient:
    def __init__(self, nats_address: str) -> None:     # injected, not global
        self._nats_address = nats_address

    def publish_event(self, event: Event) -> None:
        conn = nats.connect(self._nats_address)
        ...


# app/__main__.py — the config is read ONLY at the entry point
def main() -> None:
    config = Config.from_environ()
    nats_client = NatsClient(config.nats_address)
    order_service = OrderService(config.db_host, nats_client)
    OrderHandler(order_service).serve()
```

The test constructs a client against a local fake NATS server — no module attribute
is written, tests run in parallel. The refactoring is incremental: one clean island
at a time, pushing the global up one level per iteration, from 20 scattered accesses
down to 2 at the entry point. Full worked case — the dependency map, the
island-by-island progression, and the test payoff:
`../examples/dependency-rejection.md`.

What stays at module level, in any module: `logger = logging.getLogger(__name__)`,
constants, enums, frozen instances used as constants, exception classes. What is
allowed only in the entry point: `Config.from_environ()`, `logging.basicConfig`, the
framework's `app` object, a registry filled by hand, `asyncio.run`.

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

Build each search over `*.py` files, excluding test files; "entry point" means
`__main__.py`, `main.py`, `cli.py`, `app.py`, `wsgi.py`/`asgi.py`, or a
`wiring`/`bootstrap` module — whichever the repository uses as its composition root.

1. **Does any module declare mutable state at module level?**
   Detection: `grep -rnE '^[a-zA-Z_][a-zA-Z0-9_]* *(: *[^=]+)? *= ' --include='*.py' . | grep -v 'test_\|_test.py\|conftest'` —
   then sort the hits into three lists:
   - silent everywhere: `logger = logging.getLogger(__name__)`, an `UPPER_CASE`
     constant bound to a literal, an `Enum` or `StrEnum` class, a frozen dataclass
     instance used as a constant (`NULL_SINK = NullSink()`), an exception class, a
     `TypeVar`/`TypeAlias`/`Protocol`, `__all__`;
   - silent only in the entry point: `CONFIG = Config.from_environ()`,
     `logging.basicConfig(...)`, the framework `app = FastAPI()`, a registry filled
     by hand, `asyncio.run(main())`;
   - reported everywhere else: a module-level `dict`, `list` or `set` a function
     writes into (`REGISTRY: dict[str, Handler] = {}` next to a `register()` that
     mutates it), a module-level instance whose attributes change, a `global`
     statement (ruff `PLW0603` marks the rebind), a `_cache = None` behind a getter.
   Violation: a module-level variable that is written after import or holds
   configuration/state — reject it into a constructor-injected field.

2. **Does any import-time code write state?**
   Detection: `grep -rnE '^(if |for |with |try:|[a-z_][a-z0-9_.]*\(|[A-Z_]+\.(register|add|append|update|setdefault)\()' --include='*.py' . | grep -v 'test_\|_test.py\|conftest'` —
   a statement at column 0 that is not a `def`, a `class`, an import, a docstring or
   the binding of a literal runs when the module is imported; read each for writes
   to module-level variables or registrations with side effects (`register(...)`
   calls under the class definitions, a decorator that appends to a module list, a
   `REGION = os.environ["REGION"]` read).
   Violation: import-time code mutating module state — replace with an explicit
   constructor or factory called at the edge (Replace Import-Time Initialization
   with a Constructor).

3. **Does library code manufacture its own cancellation root?**
   Detection: `grep -rnE 'asyncio\.run\(|get_event_loop\(\)|new_event_loop\(\)|logging\.basicConfig\(' --include='*.py' . | grep -v 'test_\|_test.py\|conftest' | grep -vE '__main__\.py|/main\.py|/cli\.py|/app\.py'`
   Violation: any hit outside the entry point. A library function takes its event
   loop from the caller by being `async` (or takes an explicit task group or
   executor), and takes its logger from `logging.getLogger(__name__)`;
   `basicConfig` configures the process-wide root logger and belongs to whoever
   owns the process.

4. **Is a singleton reached sideways?**
   Detection: `grep -rnE '^_[a-z_]+ *(: *[^=]+)? *= *None$|@(functools\.)?(cache|lru_cache)\b|^_[a-z_]*lock *= *threading\.Lock\(\)' --include='*.py' .` —
   a module-level `_instance = None` with a `get_x()` that fills it, a cached
   zero-argument getter that builds a service, or a module lock guarding lazy
   construction; check whether business logic calls the getter.
   Violation: `get_x()`-style access from inside logic — construct at the edge, pass
   down. (A `functools.cache` on a pure function of its arguments is not this.)

5. **Does deep code read a global config?**
   Detection: `grep -rnE 'os\.environ|os\.getenv\(|from [a-z_.]*(env|config|settings) import [A-Z_]+|\b(CONFIG|SETTINGS|settings)\.[a-z_]+' --include='*.py' . | grep -v 'test_\|_test.py\|conftest' | grep -vE '__main__\.py|/main\.py|/cli\.py|/app\.py|/settings\.py|/config\.py'`
   Violation: config reads outside entry-point wiring — each is a dependency to
   reject upward (`../examples/dependency-rejection.md`). The one module that
   builds the `Config` from `os.environ` belongs to the entry point; the value it
   builds travels down as a parameter.

6. **Do tests mutate globals to run?**
   Detection: `grep -rnE 'monkeypatch\.(setattr|setenv|setitem)\(|mock\.patch\.dict\(.*environ|^\s+[a-z_]+\.[A-Z_]+ *= ' --include='test_*.py' --include='*_test.py' --include='conftest.py' .`
   Violation: a test writing shared state to inject a value — a monkeypatch of a
   production module's attribute or of `os.environ` to reach the code under test is
   evidence against the production code, which has a hidden dependency; fix the
   production code, not the test. (Setting the environment of a subprocess in a
   system test is the true external boundary, not this.)
