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
1. Run linter: ruff check --fix . && ruff format . && mypy
2. If linter fails → use @refactoring skill
3. If linter passes → use @pre-commit-review skill
```
