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
