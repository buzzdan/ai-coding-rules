---
name: testing
description: |
  Use when creating leaf types, after refactoring, during implementation, or when testing advice is needed.
  Automatically invoked to write tests for new types, or use as testing expert advisor.
  Covers unit, integration, and system tests with emphasis on in-memory dependencies.
  Ensures 100% coverage on leaf types with public API testing.
---

<objective>
Principles and patterns for writing effective Go tests.
Writes tests autonomously based on code structure and type design, and serves as testing expert advisor.

**Reference**: See `reference.md` for comprehensive testutils patterns and DSL examples.
</objective>

<quick_start>
1. **Identify test level** needed (unit/integration/system)
2. **Choose structure**: table-driven (simple) or testify suites (complex setup)
3. **Write in pkg_test package** - test public API only
4. **Use in-memory implementations** from testutils
5. **Avoid pitfalls**: No time.Sleep, no conditionals in test cases

Ready after tests? Run linter: `task lintwithfix`
</quick_start>

<when_to_use>
<automatic_invocation>
- **Automatically invoked** by @linter-driven-development during Phase 2 (Implementation)
- **Automatically invoked** by @refactoring when new isolated types are created
- **Automatically invoked** by @code-designing after designing new types
- **After creating new leaf types** - Types that should have 100% unit test coverage
- **After extracting functions** during refactoring that create testable units
</automatic_invocation>

<manual_invocation>
- User explicitly requests tests to be written
- User asks for testing advice, recommendations, or "what to do"
- When testing strategy is unclear (table-driven vs testify suites)
- When choosing between dependency levels (in-memory vs binary vs test-containers)
- When adding tests to existing untested code
- When user needs testing expert guidance or consultation
</manual_invocation>
</when_to_use>

<philosophy>
**Test only the public API**
- Use `pkg_test` package name
- Test types through their constructors
- No testing private methods/functions

**Prefer real implementations over mocks**
- Use in-memory implementations (fastest, no external deps)
- Use HTTP test servers (httptest)
- Use temp files/directories
- Test with actual dependencies when beneficial

**Coverage targets**
- Leaf types: 100% unit test coverage
- Orchestrating types: Integration tests
- Critical workflows: System tests
</philosophy>

<test_pyramid>
Three levels of testing, each serving a specific purpose:

<unit_tests level="base">
- Test leaf types in isolation
- Fast, focused, no external dependencies
- 100% coverage target for leaf types
- Use `pkg_test` package, test public API only
</unit_tests>

<integration_tests level="middle">
- Test seams between components
- Test workflows across package boundaries
- Use real or in-memory implementations
- Verify components work together correctly
</integration_tests>

<system_tests level="top">
- Black box testing from `tests/` folder
- Test entire system via CLI/API
- Test critical end-to-end workflows
- **Dependency options**: in-memory mocks, binaries (exec.Command), or test-containers
- Prefer in-memory when possible, but use appropriate level for the test
</system_tests>
</test_pyramid>

<reusable_infrastructure>
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
</reusable_infrastructure>

<workflow>

<unit_tests_workflow>
**Purpose**: Test leaf types in isolation, 100% coverage target

1. **Identify leaf types** - Self-contained types with logic
2. **Choose structure** - Table-driven (simple) or testify suites (complex setup)
3. **Write in pkg_test package** - Test public API only
4. **Use in-memory implementations** - From testutils or local implementations
5. **Avoid pitfalls** - No time.Sleep, no conditionals in cases, no private method tests

**Test structure:**
- Table-driven: Separate success/error test functions (complexity = 1)
- Testify suites: Only for complex infrastructure setup (HTTP servers, DBs)
- Always use named struct fields (linter reorders fields)

See reference.md for detailed patterns and examples.
</unit_tests_workflow>

<integration_tests_workflow>
**Purpose**: Test seams between components, verify they work together

1. **Identify integration points** - Where packages/components interact
2. **Choose dependencies** - Prefer: in-memory > binary > test-containers
3. **Write tests** - In `pkg_test` or `integration_test.go` with build tags
4. **Test workflows** - Cover happy path and error scenarios across boundaries
5. **Use real or testutils implementations** - Avoid heavy mocking

**File organization:**
```go
//go:build integration

package user_test

// Test Service + Repository + real/mock dependencies
```

See reference.md for integration test patterns with dependencies.
</integration_tests_workflow>

<system_tests_workflow>
**Purpose**: Black box test entire system, critical end-to-end workflows

1. **Place in tests/ folder** - At project root, separate from packages
2. **Test via CLI/API** - exec.Command for CLI, HTTP client for APIs
3. **Choose dependency level** based on what you're testing:
   - **In-memory**: Fastest, use when testing your code's behavior
   - **Binary**: exec.Command to run real executables in separate process
   - **Test-containers**: When you need real external services (DB, message queue)
4. **Test critical workflows** - User journeys, not every edge case

**Example with in-memory mock:**
```go
// tests/cli_test.go - Testing CLI against mock API
func TestCLI_UserWorkflow(t *testing.T) {
    mockAPI := testutils.NewMockServer().
        OnGET("/users/1").RespondJSON(200, user).
        Build() // In-memory httptest.Server
    defer mockAPI.Close()

    cmd := exec.Command("./myapp", "get-user", "1",
        "--api-url", mockAPI.URL())
    output, err := cmd.CombinedOutput()
    // Assert on output
}
```

**Example with binary executable:**
```go
// tests/integration_test.go - Testing against real service binary
func TestSystem_WithRealService(t *testing.T) {
    // Start service binary in background
    svc := exec.Command("./myservice", "--port", "8080")
    svc.Start()
    defer svc.Process.Kill()

    // Wait for service to be ready
    waitForHealthy(t, "http://localhost:8080/health")

    // Run tests against real service
    resp, err := http.Get("http://localhost:8080/api/users")
    // Assert on response
}
```

See reference.md for comprehensive system test patterns including test-containers.
</system_tests_workflow>

</workflow>

<key_patterns>
**Table-Driven Tests (Cyclomatic Complexity = 1):**
- **NEVER use wantErr bool** - Splits test logic, adds conditionals
- **Max complexity = 1 inside t.Run()** - No if/else, no switch, no conditionals
- Separate success and error test functions (TestFoo_Success, TestFoo_Error)
- Always use named struct fields (linter reorders fields)

```go
// BAD - wantErr adds conditional, complexity > 1
tests := []struct {
    input   string
    want    string
    wantErr bool  // NEVER DO THIS
}{...}
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        got, err := Parse(tt.input)
        if tt.wantErr {  // <- Conditional! Complexity > 1
            require.Error(t, err)
        } else {
            require.NoError(t, err)
            require.Equal(t, tt.want, got)
        }
    })
}

// GOOD - Separate functions, complexity = 1
func TestParse_Success(t *testing.T) {
    tests := []struct {
        name  string
        input string
        want  string
    }{...}
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := Parse(tt.input)
            require.NoError(t, err)      // No conditionals
            require.Equal(t, tt.want, got)
        })
    }
}

func TestParse_Error(t *testing.T) {
    tests := []struct {
        name  string
        input string
    }{...}
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            _, err := Parse(tt.input)
            require.Error(t, err)  // No conditionals
        })
    }
}
```

**Testify Suites:**
- Only for complex infrastructure (HTTP servers, DBs, OpenTelemetry)
- SetupSuite/TearDownSuite for expensive shared setup
- SetupTest/TearDownTest for per-test isolation

**Synchronization:**
- Never use time.Sleep (flaky, slow)
- Use channels with select/timeout for async operations
- Use sync.WaitGroup for concurrent operations

See reference.md for complete patterns with code examples.
</key_patterns>

<output_format>
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
</output_format>

<testing_checklist>
<unit_tests_checklist>
- [ ] All unit tests in pkg_test package
- [ ] Testing public API only (no private methods)
- [ ] Table-driven tests use named struct fields
- [ ] No conditionals in test cases (complexity = 1)
- [ ] Using in-memory implementations from testutils
- [ ] No time.Sleep (using channels/waitgroups)
- [ ] Leaf types have 100% coverage
</unit_tests_checklist>

<integration_tests_checklist>
- [ ] Test seams between components
- [ ] Use in-memory or binary dependencies (avoid Docker)
- [ ] Build tags for optional execution (`//go:build integration`)
- [ ] Cover happy path and error scenarios across boundaries
- [ ] Real or testutils implementations (minimal mocking)
</integration_tests_checklist>

<system_tests_checklist>
- [ ] Located in tests/ folder at project root
- [ ] Black box testing via CLI/API
- [ ] Appropriate dependency level chosen (in-memory, binary, or test-containers)
- [ ] Tests critical end-to-end workflows
- [ ] Dependencies documented (what's needed to run tests)
- [ ] CI-compatible (either fast in-memory or containerized setup)
</system_tests_checklist>

<test_infrastructure_checklist>
- [ ] Reusable mocks in internal/testutils/
- [ ] Test infrastructure has its own tests
- [ ] DSL provides readable test setup
- [ ] Can be exposed as CLI for manual testing
</test_infrastructure_checklist>

See reference.md for complete testing guidelines and examples.
</testing_checklist>

<success_criteria>
Testing is complete when ALL of the following are true:

- [ ] All unit tests in pkg_test package testing public API only
- [ ] Table-driven tests use named struct fields
- [ ] No wantErr bool - success and error cases in separate test functions
- [ ] Cyclomatic complexity = 1 inside t.Run() (no if/else, no switch)
- [ ] Leaf types have 100% coverage
- [ ] Integration tests cover component seams
- [ ] System tests in tests/ folder with appropriate dependency level
- [ ] No time.Sleep (using channels/waitgroups)
- [ ] Tests pass and linter approves
</success_criteria>
