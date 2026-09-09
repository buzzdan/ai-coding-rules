Build shared test infrastructure in `internal/testutils/`:
- In-memory mock servers with DSL (HTTP, DB, file system)
- Reusable across all test levels
- Test the infrastructure itself!
- Can expose as CLI tools for manual testing

**Dependency Priority** (choose appropriate level):
1. **In-memory** (fastest): Pure Go, httptest, in-memory DB - use when testing your code's logic
2. **Binary** (isolated): Standalone executable via exec.Command - use when testing against real service
3. **Test-containers** (realistic): Programmatic Docker from Go - use when you need real external services
4. **Docker-compose** (full stack): For complex multi-service scenarios

Choose based on what you're testing, not dogmatically. In-memory is fastest but sometimes you need real services.

See reference.md for comprehensive testutils patterns and DSL examples.
