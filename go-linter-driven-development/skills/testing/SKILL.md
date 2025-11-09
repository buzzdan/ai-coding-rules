---
name: testing
description: Automatically invoked to write tests for new types, or use as testing expert advisor for guidance and recommendations. Covers unit, integration, and system tests with emphasis on in-memory dependencies. Use when creating leaf types, after refactoring, during implementation, or when testing advice is needed. Ensures 100% coverage on leaf types with public API testing.
---

# Testing Principles

Principles and patterns for writing effective Go tests.

## When to Use

### Automatic Invocation (Proactive)
- **Automatically invoked** by @linter-driven-development during Phase 2 (Implementation)
- **Automatically invoked** by @refactoring when new isolated types are created
- **Automatically invoked** by @code-designing after designing new types
- **After creating new leaf types** - Types that should have 100% unit test coverage
- **After extracting functions** during refactoring that create testable units

### Manual Invocation
- User explicitly requests tests to be written
- User asks for testing advice, recommendations, or "what to do"
- When testing strategy is unclear (table-driven vs testify suites)
- When choosing between dependency levels (in-memory vs binary vs test-containers)
- When adding tests to existing untested code
- When user needs testing expert guidance or consultation

**IMPORTANT**: This skill writes tests autonomously based on the code structure and type design, and also serves as a testing expert advisor

## Testing Philosophy

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

## Test Pyramid

Three levels of testing, each serving a specific purpose:

**Unit Tests** (Base of pyramid - most tests here)
- Test leaf types in isolation
- Fast, focused, no external dependencies
- 100% coverage target for leaf types
- Use `pkg_test` package, test public API only

**Integration Tests** (Middle - fewer than unit)
- Test seams between components
- Test workflows across package boundaries
- Use real or in-memory implementations
- Verify components work together correctly

**System Tests** (Top - fewest tests)
- Black box testing from `tests/` folder
- Test entire system via CLI/API
- Test critical end-to-end workflows
- **Strive for independence in Go** (minimize external deps)

## Reusable Test Infrastructure

Build shared test infrastructure in `internal/testutils/`:
- In-memory mock servers with DSL (HTTP, DB, file system)
- Reusable across all test levels
- Test the infrastructure itself!
- Can expose as CLI tools for manual testing

**Dependency Priority** (minimize external dependencies):
1. **In-memory** (preferred): Pure Go, httptest, in-memory DB
2. **Binary**: Standalone executable via exec.Command
3. **Test-containers**: Programmatic Docker from Go
4. **Docker-compose**: Last resort, manual testing only

Goal: System tests should be **independent in Go** when possible.

See reference.md for comprehensive testutils patterns and DSL examples.

## Workflow

### Unit Tests Workflow

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

### Integration Tests Workflow

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

### System Tests Workflow

**Purpose**: Black box test entire system, critical end-to-end workflows

1. **Place in tests/ folder** - At project root, separate from packages
2. **Test via CLI/API** - exec.Command for CLI, HTTP client for APIs
3. **Minimize external deps** - Prefer: in-memory mocks > binary > test-containers
4. **Strive for Go independence** - Pure Go tests, no Docker when possible
5. **Test critical workflows** - User journeys, not every edge case

**Example structure:**
```go
// tests/cli_test.go
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

See reference.md for comprehensive system test patterns.

## Key Test Patterns

**Table-Driven Tests:**
- Separate success and error test functions (complexity = 1)
- Always use named struct fields (linter reorders fields)
- No wantErr bool pattern (adds conditionals)

**Testify Suites:**
- Only for complex infrastructure (HTTP servers, DBs, OpenTelemetry)
- SetupSuite/TearDownSuite for expensive shared setup
- SetupTest/TearDownTest for per-test isolation

**Synchronization:**
- Never use time.Sleep (flaky, slow)
- Use channels with select/timeout for async operations
- Use sync.WaitGroup for concurrent operations

See reference.md for complete patterns with code examples.

## Output Format

After writing tests:

```
✅ TESTING COMPLETE

📊 Unit Tests:
- user/user_id_test.go: 100% (4 test cases)
- user/email_test.go: 100% (6 test cases)
- user/service_test.go: 100% (8 test cases)

🔗 Integration Tests:
- user/integration_test.go: 3 workflows tested
- Dependencies: In-memory DB, httptest mock server

🎯 System Tests:
- tests/cli_test.go: 2 end-to-end workflows
- tests/api_test.go: 1 full API workflow
- Infrastructure: In-memory mocks (pure Go, no Docker)

Test Infrastructure:
- internal/testutils/httpserver: In-memory mock API with DSL
- internal/testutils/mockdb: In-memory database mock

Test Execution:
$ go test ./...                    # All tests
$ go test -tags=integration ./...  # Include integration tests
$ go test ./tests/...              # System tests only

✅ All tests pass
✅ 100% coverage on leaf types
✅ No external dependencies required

Next Steps:
1. Run linter: task lintwithfix
2. If linter fails → use @refactoring skill
3. If linter passes → use @pre-commit-review skill
```

## Key Principles

See reference.md for:
- Table-driven test patterns
- Testify suite guidelines
- Real implementations over mocks
- Synchronization techniques
- Coverage strategies

## Testing Checklist

### Unit Tests
- [ ] All unit tests in pkg_test package
- [ ] Testing public API only (no private methods)
- [ ] Table-driven tests use named struct fields
- [ ] No conditionals in test cases (complexity = 1)
- [ ] Using in-memory implementations from testutils
- [ ] No time.Sleep (using channels/waitgroups)
- [ ] Leaf types have 100% coverage

### Integration Tests
- [ ] Test seams between components
- [ ] Use in-memory or binary dependencies (avoid Docker)
- [ ] Build tags for optional execution (`//go:build integration`)
- [ ] Cover happy path and error scenarios across boundaries
- [ ] Real or testutils implementations (minimal mocking)

### System Tests
- [ ] Located in tests/ folder at project root
- [ ] Black box testing via CLI/API
- [ ] Uses in-memory testutils mocks (pure Go)
- [ ] No external dependencies (no Docker required)
- [ ] Tests critical end-to-end workflows
- [ ] Fast execution, runs in CI without setup

### Test Infrastructure
- [ ] Reusable mocks in internal/testutils/
- [ ] Test infrastructure has its own tests
- [ ] DSL provides readable test setup
- [ ] Can be exposed as CLI for manual testing

See reference.md for complete testing guidelines and examples.
