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
