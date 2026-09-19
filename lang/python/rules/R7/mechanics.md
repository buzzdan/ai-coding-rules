- **Mechanics**: `pytest.param(..., id=...)` on every row so a failure names its
  case, and named tuple fields rather than positional tuples when a row carries more
  than two values; no `time.sleep` — `Event.wait(timeout)`, `Queue.get(timeout)` or an
  awaited future; fixtures only for real infrastructure setup (a temp directory, a
  fake server, a database), never to hide the literal a test should show; import the
  package as a consumer would (`from app import user`), never a `_private` name;
  success and error cases in separate `test_x_success`/`test_x_error` functions,
  never one table with an `expect_err` column and a branch on it.
