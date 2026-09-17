Build shared test infrastructure where the repository already keeps its test
helpers (a test-utilities package, a `conftest`, a `test/support` directory —
create one in the language's convention when none exists):
- In-memory fake servers with a DSL (HTTP, DB, file system)
- Reusable across all test levels
- Test the infrastructure itself!
- Can expose as CLI tools for manual testing

**Dependency Priority** (choose appropriate level):
1. **In-memory** (fastest): pure in-process code, an in-process HTTP server, an in-memory DB - use when testing your code's logic
2. **Binary** (isolated): a standalone executable started as a subprocess - use when testing against a real service
3. **Test-containers** (realistic): programmatic Docker from the test - use when you need real external services
4. **Docker-compose** (full stack): For complex multi-service scenarios

Choose based on what you're testing, not dogmatically. In-memory is fastest but sometimes you need real services.

The repository's own test utilities and their DSLs are the reference — match them
before inventing a shape.