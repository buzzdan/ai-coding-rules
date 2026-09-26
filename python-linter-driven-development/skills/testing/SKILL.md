---
name: testing
description: |
  Use when creating leaf types, after refactoring, during implementation, or when testing advice is needed.
  Automatically invoked to write tests for new types, or use as testing expert advisor.
  Covers the composition ladder from rung-0 unit tests to whole-system tests, with emphasis on real in-memory dependencies.
  Ensures 100% coverage on leaf types with public API testing.
---

<objective>
Principles and patterns for writing effective Python tests.
Writes tests autonomously based on code structure and type design, and serves as testing expert advisor.

**Reference**: See `reference.md` for comprehensive testutils patterns and DSL examples.
</objective>

<quick_start>
1. **Find the lowest rung** that contains the behavior (see composition_ladder)
2. **Choose structure**: `@pytest.mark.parametrize` with `pytest.param(id=...)` (simple) or fixture-backed setup (complex infrastructure)
3. **Import as a consumer would** (`from app import user`) - test public API only, never a `_private` name
4. **Compose real layers** - in-memory/in-process implementations from the repository's test-support package
5. **Avoid pitfalls**: No `time.sleep`, no conditionals in test bodies, no `mock.patch` of internal collaborators

Ready after tests? Run linter: `ruff check --fix . && ruff format . && ty check` (or `mypy`, whichever the repository configures)
</quick_start>

<when_to_use>
<automatic_invocation>
- **Automatically invoked** by @linter-driven-development in Phase 2's RED step — one failing test per behavior, placed by the composition ladder
- **Automatically invoked** by @refactoring when new isolated types are created
- **Automatically invoked** by @code-designing after designing new types
- **After creating new leaf types** - Types that should have 100% unit test coverage
- **After extracting functions** during refactoring that create testable units
</automatic_invocation>

<manual_invocation>
- User explicitly requests tests to be written
- User asks for testing advice, recommendations, or "what to do"
- When testing strategy is unclear (table-driven vs suites)
- When choosing between dependency levels (in-memory vs binary vs test-containers)
- When adding tests to existing untested code
- When user needs testing expert guidance or consultation
</manual_invocation>
</when_to_use>

<philosophy>
**Test only the public API**
- Import the package as a consumer would, so privates are unreachable
- Test types through their constructors
- No testing private methods/functions — the urge to unit-test an underscore-prefixed helper directly is a promotion signal: give the helper its own package (`../../rules/R4-helper-placement.md`), never test privates.

**No mocks — and a type that only satisfies a production interface in a test IS a mock**
- A "fake" is a *real implementation with fake data* (embedded DB, in-process HTTP server, fake binary, temp dir) — NOT a type written to satisfy a dependency interface, and NOT a patched-in stand-in.
- Terminology: the banned "mock" is an interface-injected or patched-in double. The "in-memory mock servers" elsewhere in this skill are fakes in this sense — real servers speaking the real protocol with configurable fake data — and remain the recommended stand-in for external APIs you don't control (wired via URL/config, never via a production interface).
- Use in-memory implementations (fastest, no external deps), in-process HTTP test servers, temp files/directories, or the real dependency.
- **Orchestrators are tested by wiring their real collaborators** (real Store/Evaluator over embedded DB + in-process external services), never by injecting doubles.
- If you are tempted to add an interface so a test can inject a fake, stop — that interface is a test-only smell. Depend on the concrete type instead (see @code-designing and `../../rules/R6-test-only-interfaces.md`).

**Coverage targets**
- Rung 0 (leaf types): 100% unit test coverage
- Higher rungs (orchestrating types): cover the delta each rung adds — its seams and emergent behaviors
- Critical workflows: top-rung (system) tests

**Assertions**: the bare `assert` with pytest's rewriting is the default (`assert got == want`, `pytest.raises(ValueError, match="...")`), but project convention wins — match the codebase you're in; never add a second assertion library.
</philosophy>

<composition_ladder>
Tests sit on a ladder of real composition, not a pyramid of layer percentages.

**Rung 0 — pure leaf types.** No I/O, no concurrent tasks, no production dependencies.
Tests are plain constructions plus assertions: slice literals, value tables.
100% coverage is expected here — leaf types own most of the logic.

**Each rung above adds exactly one real production layer** — the real
implementation, never a mock. In-memory/in-process infrastructure counts as the
real layer: an in-process HTTP test server, SQLite in memory, `tmp_path` files, a broker
started as a subprocess.

**Fake only the true external boundary** — the thing you genuinely cannot run
in-process (a third-party SaaS API, a hardware device). Everything inside the
boundary composes real.

**Placement rule: test each behavior at the lowest rung that contains it.** A
behavior expressible at rung 0 never gets tested through a rung-2 harness.

**Each rung tests its delta plus emergent behaviors**: the wiring/seams that rung
adds and behaviors that only exist through composition — not a re-test of
lower-rung logic (some overlap with leaf coverage is acceptable for orchestrators,
per `../../rules/R7-test-placement.md`).

The **top rung** is the whole system composed: black-box tests from `tests/` via
CLI/API, only the external boundary faked.

**Obligation table** — a template; adapt the rows per project and keep the adapted
table in the project docs:

| Kind of change | Owes a test at |
|---|---|
| New leaf type, or new behavior on one | Rung 0 |
| New seam between components X and Y | Rung 1 — the first rung containing the seam |
| New wiring through an infrastructure layer (queue, DB, RPC) | The rung that adds that layer |
| New externally observable behavior | Top rung |

The ladder is defined here; the placement review contract (falsifying questions)
lives in `../../rules/R7-test-placement.md`.
</composition_ladder>

<reusable_infrastructure>
Build shared test infrastructure in an importable test-support package
(`<pkg>/testing/` or `tests/support/`; `conftest.py` holds only the fixtures that
hand it out):
- In-memory fake servers with a DSL (HTTP, DB, file system)
- Reusable across all test levels
- Test the infrastructure itself!
- Can expose as CLI tools for manual testing

**Dependency Priority** (choose appropriate level):
1. **In-memory** (fastest): pure Python, an in-process HTTP test server, SQLite in memory - use when testing your code's logic
2. **Binary** (isolated): a standalone executable via `subprocess.Popen` - use when testing against a real service
3. **Test-containers** (realistic): programmatic Docker from the test (`testcontainers`) - use when you need real external services
4. **Docker-compose** (full stack): For complex multi-service scenarios

Choose based on what you're testing, not dogmatically. In-memory is fastest but sometimes you need real services.

See reference.md for the pytest harness catalogue and DSL examples.
</reusable_infrastructure>

<workflow>

<unit_tests_workflow>
**Purpose**: Rung 0 — test leaf types in isolation, 100% coverage target

1. **Identify leaf types** - Self-contained types with logic
2. **Choose structure** - `@pytest.mark.parametrize` (simple) or fixture-backed setup (complex infrastructure)
3. **Import as a consumer would** - `from app import user`; never a `_private` name
4. **Use in-memory implementations** - From the repository's test-support package or local implementations
5. **Avoid pitfalls** - No `time.sleep`, no conditionals in test bodies, no `_private` tests, no `mock.patch` of collaborators

**Test structure:**
- Parametrized: Separate success/error test functions (complexity = 1)
- Fixtures: Only for real infrastructure (`tmp_path`, a fake server, a database) — never to hide the literal a test should show
- `pytest.param(..., id=...)` on every row; named fields when a row carries more than two values

See reference.md for detailed patterns and examples.
</unit_tests_workflow>

<integration_tests_workflow>
**Purpose**: Middle rungs — each adds one real layer; test the seams and emergent behaviors that layer brings

1. **Identify integration points** - Where packages/components interact
2. **Choose dependencies** - Prefer: in-memory > binary > test-containers
3. **Write tests** - Imported as a consumer would, in a `test_integration.py` beside the component or under `tests/integration/`, marked `@pytest.mark.integration` (register the marker in `pyproject.toml` so `pytest -m "not integration"` skips them)
4. **Test workflows** - Cover happy path and error scenarios across boundaries
5. **Use real or test-support implementations** - No `mock.patch` of internal collaborators

**File organization:**
```python
# user/test_integration.py
import pytest

pytestmark = pytest.mark.integration

# Service + Repository + real in-memory dependencies
```

See reference.md for integration test patterns with dependencies.
</integration_tests_workflow>

<system_tests_workflow>
**Purpose**: Top rung — black box test the entire system, critical end-to-end workflows

1. **Place in tests/ folder** - At project root, separate from packages
2. **Test via CLI/API** - `subprocess.run` for a CLI, an HTTP client for an API
3. **Choose dependency level** based on what you're testing:
   - **In-memory**: Fastest, use when testing your code's behavior
   - **Binary**: `subprocess.Popen` to run the real executable in a separate process
   - **Test-containers**: When you need real external services (DB, message queue)
4. **Test critical workflows** - User journeys, not every edge case

**Example with an in-process fake:**
```python
# tests/test_cli.py - the CLI against a fake API
def test_cli_prints_the_user(fake_api: FakeServer) -> None:
    fake_api.on_get("/users/1").respond_json(200, USER)

    result = subprocess.run(
        [sys.executable, "-m", "myapp", "get-user", "1", "--api-url", fake_api.url],
        capture_output=True, text=True, check=False,
    )

    assert result.returncode == 0
    assert "alice" in result.stdout
```

**Example with a real service binary:**
```python
# tests/test_system.py - against the real service process
def test_lists_users_from_the_running_service(service: RunningService) -> None:
    # `service` is a fixture: it starts the process, polls /health with a
    # deadline (never a fixed sleep), and terminates and waits in teardown
    with urllib.request.urlopen(f"{service.url}/api/users") as resp:
        assert resp.status == 200
```

See reference.md for the harnesses behind `fake_api` and `service`, and for test-containers.
</system_tests_workflow>

</workflow>

<key_patterns>
**Parametrized Tests (Cyclomatic Complexity = 1):**
- **NEVER add an `expect_err` column** - It splits test logic and puts `if expect_err:` in the body
- **Max complexity = 1 inside a test body** - No if/else, no match, no conditionals
- Separate success and error test functions (`test_parse_policy_success`, `test_parse_policy_rejects`)
- `pytest.param(..., id="...")` on every row; a `NamedTuple` or dataclass row when a case carries more than two values
- Canonical violation, detection commands, and split pattern: `../../rules/R7-test-placement.md`; worked example in reference.md

**Fixtures and classes:**
- A fixture only for real infrastructure (`tmp_path`, a fake HTTP server, a database); a fixture that returns the literal a test should show hides the input
- `conftest.py` holds those infrastructure fixtures — session- or module-scoped for expensive shared setup, function-scoped for per-test isolation
- A `Test*` class only to group tests of one type; no setup state on `self`

**Synchronization:**
- Never use `time.sleep` (flaky, slow)
- `Event.wait(timeout)`, `Queue.get(timeout)`, `Thread.join(timeout)` for threads; `await asyncio.wait_for(...)` for tasks (pytest-asyncio or anyio, whichever the repository uses)
- Join every thread and await every task the test started before asserting

See reference.md for complete patterns with code examples.
</key_patterns>

<output_format>
After writing tests:

```
TESTING COMPLETE

Unit Tests:
- user/test_user_id.py: 100% (4 test cases)
- user/test_email.py: 100% (6 test cases)
- user/test_service.py: 100% (8 test cases)

Integration Tests:
- user/test_integration.py: 3 workflows tested
- Dependencies: in-memory repository, in-process fake HTTP server

System Tests:
- tests/test_cli.py: 2 end-to-end workflows (in-memory fakes)
- tests/test_api.py: 1 full API workflow (binary executable)
- tests/test_db.py: 1 database workflow (test-containers)

Test Infrastructure:
- app/testing/httpserver.py: in-memory fake API with DSL
- app/testing/fakedb.py: in-memory database fake
- app/testing/containers.py: test-container helpers

Test Execution:
$ pytest                              # all tests (in-memory only)
$ pytest -m integration               # integration tests
$ pytest tests/                       # system tests (may need containers)

All tests pass
100% coverage on leaf types

Next Steps:
1. Run linter: ruff check --fix . && ruff format . && ty check   # or mypy, whichever the repository configures
2. If linter fails → use @refactoring skill
3. If linter passes → use @pre-commit-review skill
```
</output_format>

<testing_checklist>
<unit_tests_checklist>
- [ ] All unit tests import the package as a consumer would (`from app import user`)
- [ ] Testing public API only (no `_private` name imported or called)
- [ ] Parametrized cases carry `pytest.param(..., id=...)` and named fields, never bare positional tuples
- [ ] No conditionals in test bodies (complexity = 1)
- [ ] Using in-memory implementations from the repository's test-support package
- [ ] No time.sleep (Event.wait, Queue.get with a timeout, an awaited future)
- [ ] Leaf types have 100% coverage
</unit_tests_checklist>

<integration_tests_checklist>
- [ ] Test seams between components
- [ ] Use in-memory or binary dependencies (avoid Docker)
- [ ] A pytest marker for optional execution (`@pytest.mark.integration`, registered in `pyproject.toml`)
- [ ] Cover happy path and error scenarios across boundaries
- [ ] Real or test-support implementations (no `mock.patch` of internal collaborators)
</integration_tests_checklist>

<system_tests_checklist>
- [ ] Located in tests/ folder at project root
- [ ] Black box testing via CLI (`subprocess.run`) or API (an HTTP client)
- [ ] Appropriate dependency level chosen (in-memory, binary, or test-containers)
- [ ] Tests critical end-to-end workflows
- [ ] Dependencies documented (what's needed to run tests)
- [ ] CI-compatible (either fast in-memory or containerized setup)
</system_tests_checklist>

<test_infrastructure_checklist>
- [ ] Reusable fakes live in an importable test-support package (`<pkg>/testing/` or `tests/support/`); `conftest.py` holds only the fixtures that hand them out
- [ ] Test infrastructure has its own tests
- [ ] DSL provides readable test setup
- [ ] Can be exposed as CLI for manual testing
</test_infrastructure_checklist>

See reference.md for the pytest harness catalogue.
</testing_checklist>

<success_criteria>
Testing is complete when ALL of the following are true:

- [ ] All unit tests import the package as a consumer would and test the public API only
- [ ] Parametrized cases carry `pytest.param(id=...)` and named fields
- [ ] No `expect_err` column - success and error cases in separate test functions
- [ ] Cyclomatic complexity = 1 inside every test body (no if/else, no match)
- [ ] Leaf types have 100% coverage
- [ ] Integration tests cover component seams
- [ ] System tests in tests/ folder with appropriate dependency level
- [ ] No `time.sleep` (Event.wait, Queue.get with a timeout, an awaited future)
- [ ] No `mock.patch` of internal collaborators
- [ ] Tests pass and linter approves
</success_criteria>
