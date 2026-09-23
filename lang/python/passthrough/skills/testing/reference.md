# Testing Reference

The pytest harness catalogue behind the testing skill. The principles — test the
public API only, real implementations over mocks, 100% on leaf types, complexity 1
inside a test — are in the skill and in `../../rules/R7-test-placement.md`; this
file shows how each is spelled with pytest.

## Contents

- [Parametrized tests](#parametrized-tests) — `pytest.param(id=...)`, named rows, the success/error split
- [Fixtures](#fixtures) — what earns a fixture and what does not; `conftest.py`
- [Synchronization](#synchronization) — waiting on threads and tasks without `time.sleep`
- [Real implementations](#real-implementations) — an in-memory repository, a fake HTTP server with a DSL
- [Subprocess and system tests](#subprocess-and-system-tests) — a service under test as a process
- [Doctests](#doctests) — the runnable example
- [Checklist](#checklist)

## Parametrized tests

`@pytest.mark.parametrize` is the case table. Every row carries an id, so a failure
names its case; a row with more than two values is a `NamedTuple` so each value has
a name. Success and error are two functions: the error function's body is one
`pytest.raises`, never an `if expect_err:`.

```python
class ParseCase(NamedTuple):
    raw: str
    attempts: int
    delay: timedelta


@pytest.mark.parametrize(
    "case",
    [
        pytest.param(ParseCase("3x100ms", 3, timedelta(milliseconds=100)), id="plain"),
        pytest.param(ParseCase("1x1s", 1, timedelta(seconds=1)), id="single-attempt"),
    ],
)
def test_parse_policy_success(case: ParseCase) -> None:
    policy = Policy.parse(case.raw)

    assert (policy.attempts, policy.delay) == (case.attempts, case.delay)


@pytest.mark.parametrize(
    ("raw", "message"),
    [
        pytest.param("0x100ms", "zero attempts", id="zero-attempts"),
        pytest.param("3x", "missing delay", id="missing-delay"),
        pytest.param("", "empty", id="empty"),
    ],
)
def test_parse_policy_rejects(raw: str, message: str) -> None:
    with pytest.raises(ValueError, match=message):
        Policy.parse(raw)
```

The canonical violation — one table with an `expect_err` column and a branch on
it — and its split are in `../../rules/R7-test-placement.md`.

## Fixtures

A fixture earns its place when it builds real infrastructure the test cannot
show inline: a temporary directory (`tmp_path`, built in), a fake server, a
database connection, a running subprocess. A fixture that returns a literal
(`@pytest.fixture def port(): return Port("api", 8080)`) hides the one input the
test is about; write the literal in the test.

`conftest.py` holds the infrastructure fixtures shared by a directory, scoped to
their cost: `scope="session"` for a server that takes a second to start,
`scope="function"` (the default) for anything with state a test can dirty. The
fakes themselves live in an importable test-support package (`<pkg>/testing/` or
`tests/support/`) so they can be tested and reused; `conftest.py` only hands them
out.

```python
# conftest.py
@pytest.fixture(scope="session")
def fake_api() -> Iterator[FakeServer]:
    with FakeServer() as server:      # __enter__ binds a port on 127.0.0.1
        yield server                  # __exit__ shuts it down and joins its thread
```

No `mock.patch` of an internal collaborator, no `MagicMock` standing in for a
class you own: give the collaborator a real in-memory implementation instead. A
patch is right only at the true external boundary — the wall clock, a socket, the
process environment in an entry-point test.

## Synchronization

Never `time.sleep` in a test. Every wait has a timeout and a subject:

```python
def test_flush_runs_after_close() -> None:
    flushed = threading.Event()
    cache = Cache(on_flush=flushed.set)

    cache.close()                      # sets the stop event and joins the worker

    assert flushed.wait(timeout=1.0)   # returns False on timeout — the assertion fails, nothing hangs
```

- Threads: `Event.wait(timeout)`, `Queue.get(timeout)`, `Thread.join(timeout)` then
  `assert not thread.is_alive()`.
- asyncio: `await asyncio.wait_for(task, timeout=1.0)`; run the test under
  pytest-asyncio or anyio, whichever the repository already uses, never both.
- The object under test exposes `close()` (or is a context manager) that stops and
  joins its own thread; the test calls it in teardown, so a leaked thread is a
  failing test, not a hang at interpreter exit.

## Real implementations

**An in-memory repository** is a class with the same public methods as the
production one and a `dict` inside. It lives in the test-support package, has its
own tests, and is what the service tests compose:

```python
class MemoryUserRepo:
    def __init__(self) -> None:
        self._by_id: dict[UserId, User] = {}

    def save(self, user: User) -> None:
        self._by_id[user.id] = user

    def get(self, user_id: UserId) -> User | None:
        return self._by_id.get(user_id)
```

**A fake HTTP server with a DSL** binds a real port on `127.0.0.1` with the
standard library's `http.server` (or `aiohttp`'s test utilities where the
repository is async), records requests, and answers by route:

```python
with FakeServer() as api:
    api.on_get("/users/1").respond_json(200, {"id": "usr_1", "name": "alice"})
    api.on_post("/users").respond_json(201, {"id": "usr_2"})

    client = UsersClient(base_url=api.url)
    assert client.get("usr_1").name == "alice"
    assert api.requests[0].path == "/users/1"
```

The fake is a real HTTP layer, so the client under test runs its real request code;
assertions read the fake's recorded requests as observable behavior, never a mock's
call list.

**SQLite in memory** (`sqlite3.connect(":memory:")`) is the in-memory database for
code that speaks SQL; the same schema migrations run against it.

## Subprocess and system tests

System tests live under `tests/` at the repository root and drive the program as a
process: `subprocess.run([sys.executable, "-m", "myapp", ...], capture_output=True,
text=True)` for a CLI, an HTTP client against a running service for an API. A
service fixture starts the process with `subprocess.Popen`, polls its health
endpoint with a deadline (never a fixed sleep), yields, then terminates and waits in
teardown. Mark them so `pytest -m "not system"` skips them in the fast loop;
register the marker in `pyproject.toml`.

Real external services come last: `testcontainers` starts a database or broker in
Docker from the test when in-memory and subprocess levels cannot represent the
behavior under test.

## Doctests

A doctest in a class or function docstring is the runnable example: happy-path
usage plus the one rejection that defines the contract, run by
`pytest --doctest-modules` (or the repository's doctest runner). Shape and budget:
the docstring menus in the documentation skill's reference.

## Checklist

- [ ] Imports the package as a consumer would; no `_private` name
- [ ] `pytest.param(id=...)` on every row; named fields past two values
- [ ] Success and error in separate functions; no conditional in a body
- [ ] Fixtures only for infrastructure; literals in the test
- [ ] No `mock.patch` of an internal collaborator
- [ ] Every wait has a timeout; every thread and task is joined
- [ ] `pytest --cov` shows 100% on leaf types
- [ ] `mutmut results` shows no untriaged survivor, with `paths_to_mutate` naming leaf packages only
