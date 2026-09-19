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
