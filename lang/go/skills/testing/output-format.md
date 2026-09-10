After writing tests:

```
TESTING COMPLETE

Unit Tests:
- user/user_id_test.go: 100% (4 test cases)
- user/email_test.go: 100% (6 test cases)
- user/service_test.go: 100% (8 test cases)

Integration Tests:
- user/integration_test.go: 3 workflows tested
- Dependencies: In-memory DB, httptest mock server

System Tests:
- tests/cli_test.go: 2 end-to-end workflows (in-memory mocks)
- tests/api_test.go: 1 full API workflow (binary executable)
- tests/db_test.go: 1 database workflow (test-containers)

Test Infrastructure:
- internal/testutils/httpserver: In-memory mock API with DSL
- internal/testutils/mockdb: In-memory database mock
- internal/testutils/containers: Test-container helpers

Test Execution:
$ go test ./...                    # All tests (in-memory only)
$ go test -tags=integration ./...  # Include integration tests
$ go test ./tests/...              # System tests (may need containers)

All tests pass
100% coverage on leaf types

Next Steps:
1. Run linter: task lintwithfix
2. If linter fails → use @refactoring skill
3. If linter passes → use @pre-commit-review skill
```
