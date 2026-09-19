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
