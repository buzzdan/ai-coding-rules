Testing is complete when ALL of the following are true:

- [ ] All unit tests import the code as a consumer would and test the public API only
- [ ] Case tables name every field or parameter
- [ ] No success-or-error flag - success and error cases in separate test functions
- [ ] Cyclomatic complexity = 1 inside every case (no if/else, no switch)
- [ ] Leaf types have 100% coverage
- [ ] Integration tests cover component seams
- [ ] System tests in tests/ folder with appropriate dependency level
- [ ] No sleeps (events, channels or futures with a timeout)
- [ ] Tests pass and linter approves