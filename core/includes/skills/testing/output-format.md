After writing tests:

```
TESTING COMPLETE

Unit Tests:
- user/user_id{{.TestGlob}}: 100% (4 test cases)
- user/email{{.TestGlob}}: 100% (6 test cases)
- user/service{{.TestGlob}}: 100% (8 test cases)

Integration Tests:
- user/integration{{.TestGlob}}: 3 workflows tested
- Dependencies: in-memory DB, in-process fake API server

System Tests:
- tests/cli{{.TestGlob}}: 2 end-to-end workflows (in-memory fakes)
- tests/api{{.TestGlob}}: 1 full API workflow (binary executable)
- tests/db{{.TestGlob}}: 1 database workflow (test-containers)

Test Infrastructure:
- <test utilities>/httpserver: in-memory fake API with DSL
- <test utilities>/fakedb: in-memory database fake
- <test utilities>/containers: test-container helpers

Test Execution:
$ <the repository's test command>                 # all tests (in-memory only)
$ <the same command, integration marker enabled>  # include integration tests
$ <the same command over tests/>                  # system tests (may need containers)

All tests pass
100% coverage on leaf types

Next Steps:
1. Run the repository's lint command with its fix flag
2. If linter fails → use @refactoring skill
3. If linter passes → use @pre-commit-review skill
```