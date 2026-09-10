**Table-Driven Tests (Cyclomatic Complexity = 1):**
- **NEVER use wantErr bool** - Splits test logic, adds conditionals
- **Max complexity = 1 inside t.Run()** - No if/else, no switch, no conditionals
- Separate success and error test functions (TestFoo_Success, TestFoo_Error)
- Always use named struct fields (linter reorders fields)
- Canonical violation, detection commands, and split pattern: `../../rules/R7-test-placement.md`; worked example in reference.md

**Testify Suites:**
- Only for complex infrastructure (HTTP servers, DBs, OpenTelemetry)
- SetupSuite/TearDownSuite for expensive shared setup
- SetupTest/TearDownTest for per-test isolation

**Synchronization:**
- Never use time.Sleep (flaky, slow)
- Use channels with select/timeout for async operations
- Use sync.WaitGroup for concurrent operations

See reference.md for complete patterns with code examples.
