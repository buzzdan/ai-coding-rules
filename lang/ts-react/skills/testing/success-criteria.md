Testing is complete when ALL of the following are true:

- [ ] All unit tests import the module as a consumer would and test the exported API only
- [ ] `it.each` rows carry a `name` and named fields
- [ ] No `expectError` column - success and error cases in separate `it`s
- [ ] Cyclomatic complexity = 1 inside every test body (no if/else, no switch, no ternary)
- [ ] Leaf types have 100% coverage
- [ ] Integration tests cover the page → hook → `apiClient` seams against MSW handlers
- [ ] System tests in `e2e/` or `tests/` with appropriate dependency level, run only when asked
- [ ] No `setTimeout` waits (`findBy*`, `waitFor`, fake timers advanced explicitly)
- [ ] No `vi.mock` of an internal hook or service
- [ ] Tests pass and linter approves
