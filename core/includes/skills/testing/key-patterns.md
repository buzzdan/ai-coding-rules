**Case Tables (Cyclomatic Complexity = 1):**
- **NEVER fuse success and error cases behind a flag** - It splits test logic and adds conditionals
- **Max complexity = 1 inside a case** - No if/else, no switch, no conditionals
- Separate success and error test functions (TestFoo_Success, TestFoo_Error)
- Name every case field or parameter; positional tuples hide what each value means
- Canonical violation, detection commands, and split pattern: `../../rules/R7-test-placement.md`

**Suites and fixtures:**
- Only for complex infrastructure (HTTP servers, DBs, telemetry)
- Suite-level setup/teardown for expensive shared setup
- Per-test setup/teardown for per-test isolation

**Synchronization:**
- Never sleep to synchronize (flaky, slow)
- Wait on an event, channel or future with a timeout for async operations
- Join concurrent work through its group or wait primitive before asserting

The repository's test framework decides how each of these is spelled; match it.