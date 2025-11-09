---
name: testing
description: Principles and patterns for writing effective Go tests. Use during implementation for test structure guidance, choosing between table-driven tests vs testify suites, or deciding between real implementations vs mocks. Emphasizes testing public API only with 100% coverage on leaf types.
---

# Testing Principles

Principles and patterns for writing effective Go tests.

## When to Use
- During implementation (tests + code in parallel)
- When testing strategy is unclear
- When structuring table-driven tests or testify suites
- When choosing between real implementations vs mocks

## Testing Philosophy

**Test only the public API**
- Use `pkg_test` package name
- Test types through their constructors
- No testing private methods/functions

**Prefer real implementations over mocks**
- Use HTTP test servers
- Use temp files/directories
- Use in-memory databases
- Test with actual dependencies (integration-style)

**Coverage targets**
- Leaf types: 100% unit test coverage
- Orchestrating types: Integration tests

## Workflow

### 1. Identify What to Test
- **Leaf types**: Self-contained types with logic
  - Test all public methods
  - Test validation in constructors
  - Cover happy path + edge cases + errors

- **Orchestrating types**: Types that coordinate others
  - Test workflows/seams between components
  - Use real implementations, not mocks

### 2. Choose Test Structure

**Table-Driven Tests** - Use when:
- Each test case has cyclomatic complexity = 1
- Testing simple, focused scenarios
- No conditionals needed in test cases

**Testify Suites** - Use ONLY when:
- Complex infrastructure setup needed (mock servers, DBs)
- Expensive setup/teardown shared across tests
- OpenTelemetry or similar complex testing infrastructure

### 3. Write Tests in pkg_test Package
```go
package user_test  // External package

import (
    "testing"
    "github.com/yourorg/project/user"
    "github.com/stretchr/testify/assert"
)

func TestUserService_CreateUser(t *testing.T) {
    // Test public API only
}
```

### 4. Use Real Implementations
```go
// ✅ Real implementations
repo := user.NewInMemoryRepository()
notifier := user.NewTestEmailer()  // Writes to buffer, not real email

svc, err := user.NewUserService(repo, notifier)
require.NoError(t, err)

// Test with real dependencies
err = svc.CreateUser(ctx, testUser)
assert.NoError(t, err)
```

### 5. Avoid Common Pitfalls
- ❌ No time.Sleep (use channels/waitgroups)
- ❌ No conditionals in test cases (complexity = 1)
- ❌ No testing private methods
- ❌ No heavy mocking

## Test Patterns

### Pattern 1: Table-Driven Tests (Separate Success/Error)

**Correct**: Separate success and error cases to maintain complexity = 1

```go
// Success cases - no conditionals
func TestNewUserID_Success(t *testing.T) {
    tests := []struct {
        name  string
        input string
        want  user.UserID
    }{
        {
            name:  "valid ID",
            input: "usr_123",
            want:  user.UserID("usr_123"),
        },
        {
            name:  "with numbers",
            input: "usr_456",
            want:  user.UserID("usr_456"),
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := user.NewUserID(tt.input)

            require.NoError(t, err)
            assert.Equal(t, tt.want, got)
        })
    }
}

// Error cases - no conditionals
func TestNewUserID_Error(t *testing.T) {
    tests := []struct {
        name  string
        input string
    }{
        {name: "empty ID", input: ""},
        {name: "whitespace", input: "   "},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            _, err := user.NewUserID(tt.input)

            assert.Error(t, err)
        })
    }
}
```

**Key**:
- ALWAYS use named struct fields (linter reorders fields)
- NO wantErr bool pattern (violates complexity = 1)
- Separate success and error test functions

### Pattern 2: Testify Suite (Complex Setup)
```go
type ServiceSuite struct {
    suite.Suite
    server   *httptest.Server
    db       *sql.DB
    tempDir  string
}

func (s *ServiceSuite) SetupSuite() {
    // Expensive setup once for all tests
    s.server = httptest.NewServer(handler)
    s.db = setupTestDB()
}

func (s *ServiceSuite) TearDownSuite() {
    s.server.Close()
    s.db.Close()
}

func (s *ServiceSuite) SetupTest() {
    // Per-test setup
    s.tempDir, _ = os.MkdirTemp("", "test")
}

func (s *ServiceSuite) TearDownTest() {
    os.RemoveAll(s.tempDir)
}

func (s *ServiceSuite) TestSomething() {
    // Use s.server, s.db, s.tempDir
}

func TestServiceSuite(t *testing.T) {
    suite.Run(t, new(ServiceSuite))
}
```

### Pattern 3: Synchronization (No time.Sleep)
```go
// ✅ Use channels
func TestAsyncWork(t *testing.T) {
    done := make(chan struct{})

    go func() {
        doWork()
        close(done)
    }()

    select {
    case <-done:
        // Success
    case <-time.After(1 * time.Second):
        t.Fatal("timeout")
    }
}

// ✅ Use waitgroups
func TestConcurrentWork(t *testing.T) {
    var wg sync.WaitGroup
    wg.Add(10)

    for i := 0; i < 10; i++ {
        go func() {
            defer wg.Done()
            doWork()
        }()
    }

    wg.Wait()
    // Assert results
}
```

## Output Format

After writing tests:

```
✅ TESTING COMPLETE

Test Coverage:
- user/user_id_test.go: 100% (NewUserID, String)
- user/email_test.go: 100% (NewEmail, Validate)
- user/service_test.go: 92% (CreateUser, GetUser, UpdateUser)

Test Structure:
- Table-driven tests: 15 test cases
- Integration tests: 3 workflows
- Real implementations used: InMemoryRepository, TestEmailer

Test Execution:
$ go test ./user/...
ok      github.com/yourorg/project/user  0.123s

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

Before considering tests complete:
- [ ] All tests in pkg_test package
- [ ] Testing public API only (no private methods)
- [ ] Table-driven tests use named struct fields
- [ ] No conditionals in test cases (complexity = 1)
- [ ] Using real implementations, not mocks
- [ ] No time.Sleep (using channels/waitgroups)
- [ ] Leaf types have 100% coverage
- [ ] Integration tests cover orchestrating types

See reference.md for complete testing guidelines and examples.
