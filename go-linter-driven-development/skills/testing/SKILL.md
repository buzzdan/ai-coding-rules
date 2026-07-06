---
name: testing
description: |
  Use when creating leaf types, after refactoring, during implementation, or when testing advice is needed.
  Automatically invoked to write tests for new types, or use as testing expert advisor.
  Covers the composition ladder from rung-0 unit tests to whole-system tests, with emphasis on real in-memory dependencies.
  Ensures 100% coverage on leaf types with public API testing.
---

<objective>
Principles and patterns for writing effective Go tests.
Writes tests autonomously based on code structure and type design, and serves as testing expert advisor.

**Reference**: See `reference.md` for comprehensive testutils patterns and DSL examples.
</objective>

<quick_start>
1. **Find the lowest rung** that contains the behavior (see composition_ladder)
2. **Choose structure**: table-driven (simple) or testify suites (complex setup)
3. **Write in pkg_test package** - test public API only
4. **Compose real layers** - in-memory/in-process implementations from testutils
5. **Avoid pitfalls**: No time.Sleep, no conditionals in test cases

Ready after tests? Run linter: `task lintwithfix`
</quick_start>

<when_to_use>
<automatic_invocation>
- **Automatically invoked** by @linter-driven-development during Phase 1 (Implementation Foundation)
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
- No testing private methods/functions — the urge to unit-test an unexported helper directly is a promotion signal: give the helper its own package (`../../rules/R4-helper-placement.md`), never test privates.

**No mocks — and a struct that only satisfies a production interface in a test IS a mock**
- A "fake" is a *real implementation with fake data* (embedded DB, `httptest` server, fake binary, temp dir) — NOT a struct written to satisfy a dependency interface.
- Terminology: the banned "mock" is an interface-injected struct double. The "in-memory mock servers" elsewhere in this skill (testutils DSL, `httptest` wrappers) are fakes in this sense — real servers speaking the real protocol with configurable fake data — and remain the recommended stand-in for external APIs you don't control (wired via URL/config, never via a production interface).
- Use in-memory implementations (fastest, no external deps), HTTP test servers (httptest), temp files/directories, or the real dependency.
- **Orchestrators are tested by wiring their real collaborators** (real Store/Evaluator over embedded DB + `httptest` external services), never by injecting doubles.
- If you are tempted to add an interface so a test can inject a fake, stop — that interface is a test-only smell. Depend on the concrete type instead (see @code-designing and @pre-commit-review §9).

**Coverage targets**
- Rung 0 (leaf types): 100% unit test coverage
- Higher rungs (orchestrating types): cover the delta each rung adds — its seams and emergent behaviors
- Critical workflows: top-rung (system) tests

**Assertions**: testify is the default, but project convention wins (e.g. goweka uses stdlib assertions) — match the codebase you're in.
</philosophy>

<composition_ladder>
Tests sit on a ladder of real composition, not a pyramid of layer percentages.

**Rung 0 — pure leaf types.** No I/O, no goroutines, no production dependencies.
Tests are plain constructions plus assertions: slice literals, value tables.
100% coverage is expected here — leaf types own most of the logic.

**Each rung above adds exactly one real production layer** — the real
implementation, never a mock. In-memory/in-process infrastructure counts as the
real layer: httptest server, bufconn gRPC, in-memory NATS, temp files, embedded
VictoriaMetrics.

**Fake only the true external boundary** — the thing you genuinely cannot run
in-process (a third-party SaaS API, a hardware device). Everything inside the
boundary composes real.

**Placement rule: test each behavior at the lowest rung that contains it.** A
behavior expressible at rung 0 never gets tested through a rung-2 harness.

**Each rung tests its delta plus emergent behaviors**: the wiring/seams that rung
adds and behaviors that only exist through composition — not a re-test of
lower-rung logic (some overlap with leaf coverage is acceptable for orchestrators,
per `../../rules/R7-test-placement.md`).

The **top rung** is the whole system composed: black-box tests from `tests/` via
CLI/API, only the external boundary faked.

**Obligation table** — a template; adapt the rows per project and keep the adapted
table in the project docs:

| Kind of change | Owes a test at |
|---|---|
| New leaf type, or new behavior on one | Rung 0 |
| New seam between components X and Y | Rung 1 — the first rung containing the seam |
| New wiring through an infrastructure layer (queue, DB, RPC) | The rung that adds that layer |
| New externally observable behavior | Top rung |

The ladder is defined here; the placement review contract (falsifying questions)
lives in `../../rules/R7-test-placement.md`.
</composition_ladder>

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
**Purpose**: Rung 0 — test leaf types in isolation, 100% coverage target

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
**Purpose**: Middle rungs — each adds one real layer; test the seams and emergent behaviors that layer brings

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
**Purpose**: Top rung — black box test the entire system, critical end-to-end workflows

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
