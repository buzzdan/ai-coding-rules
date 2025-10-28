# Testing Reference

Complete guide to Go testing principles and patterns.

## Core Testing Principles

### 1. Test Only Public API
- **Use `pkg_test` package name** - Forces external perspective
- **Test types via constructors** - No direct struct initialization
- **No testing private methods** - If you need to test it, make it public or rethink design

```go
// ✅ Good
package user_test

import "github.com/yourorg/project/user"

func TestService_CreateUser(t *testing.T) {
    // Test through public API
    svc, _ := user.NewUserService(repo, notifier)
    err := svc.CreateUser(ctx, testUser)
    // ...
}

// ❌ Bad
package user

func TestInternalValidation(t *testing.T) {
    // Testing private function
    result := validateEmailInternal("test@example.com")
    // ...
}
```

### 2. Avoid Mocks - Use Real Implementations
Instead of mocks, use:
- **HTTP test servers** (`httptest` package)
- **Temp files/directories** (`os.CreateTemp`, `os.MkdirTemp`)
- **In-memory databases** (SQLite in-memory, or custom in-memory implementations)
- **Test implementations** (TestEmailer that writes to buffer)

```go
// ❌ Bad - Heavy mocking
mockRepo := &MockRepository{}
mockRepo.On("Save", mock.Anything).Return(nil)

// ✅ Good - Real implementation
repo := user.NewInMemoryRepository()  // Real implementation
svc, _ := user.NewUserService(repo, notifier)
```

**Benefits:**
- Tests are more reliable (no mock setup fragility)
- Tests verify actual behavior
- Easier to maintain (no mock expectations)

### 3. Coverage Strategy

**Leaf Types** (self-contained):
- **Target**: 100% unit test coverage
- **Why**: Core logic must be bulletproof
- **How**: Test all public methods, all edge cases

**Orchestrating Types** (coordinate others):
- **Target**: Integration test coverage
- **Why**: Test seams between components
- **How**: Test with real implementations, cover workflows

**Goal**: Most logic in leaf types (easier to test and maintain)

---

## Table-Driven Tests

### When to Use
- Each test case has **cyclomatic complexity = 1**
- No conditionals inside t.Run()
- Simple, focused testing scenarios

### Pattern
```go
func TestNewUserID(t *testing.T) {
    tests := []struct {
        name    string    // Test case name
        input   string    // Input to function
        want    UserID    // Expected result
        wantErr bool      // Expect error?
    }{
        {
            name:    "valid ID",
            input:   "usr_123",
            want:    UserID("usr_123"),
            wantErr: false,
        },
        {
            name:    "empty ID returns error",
            input:   "",
            want:    UserID(""),  // Zero value
            wantErr: true,
        },
        {
            name:    "whitespace ID returns error",
            input:   "   ",
            want:    UserID(""),
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := NewUserID(tt.input)

            if tt.wantErr {
                assert.Error(t, err)
                return
            }

            assert.NoError(t, err)
            assert.Equal(t, tt.want, got)
        })
    }
}
```

### Critical Rule: Named Struct Fields
**ALWAYS use named struct fields** - Linter reorders fields, breaking unnamed initialization

```go
// ❌ BAD - Breaks when linter reorders fields
tests := []struct {
    name   string
    input  int
    want   string
}{
    {"test1", 42, "result"},  // Will break if linter reorders
}

// ✅ GOOD - Works regardless of field order
tests := []struct {
    name   string
    input  int
    want   string
}{
    {name: "test1", input: 42, want: "result"},  // Always works
}
```

### Separate Success and Error Cases
Keep cyclomatic complexity = 1 by separating success and error tests:

```go
// ✅ Good - Separate functions
func TestNewUserID_Success(t *testing.T) {
    tests := []struct {
        name  string
        input string
        want  UserID
    }{
        {name: "valid ID", input: "usr_123", want: UserID("usr_123")},
        {name: "with numbers", input: "usr_456", want: UserID("usr_456")},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := NewUserID(tt.input)
            assert.NoError(t, err)
            assert.Equal(t, tt.want, got)
        })
    }
}

func TestNewUserID_Errors(t *testing.T) {
    tests := []struct {
        name  string
        input string
    }{
        {name: "empty ID", input: ""},
        {name: "whitespace", input: "   "},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            _, err := NewUserID(tt.input)
            assert.Error(t, err)
        })
    }
}
```

---

## Testify Suites

### When to Use
ONLY for complex test infrastructure setup:
- Mock HTTP servers
- Database connections
- OpenTelemetry testing setup (providers, exporters)
- Temporary files/directories needing cleanup
- Shared expensive setup/teardown

### When NOT to Use
- Simple unit tests (use table-driven instead)
- Tests without complex setup
- Basic scenarios

### Pattern
```go
package user_test

import (
    "database/sql"
    "net/http/httptest"
    "os"
    "testing"

    "github.com/stretchr/testify/suite"
)

type ServiceSuite struct {
    suite.Suite
    server   *httptest.Server
    db       *sql.DB
    tempDir  string
    svc      *user.UserService
}

// SetupSuite runs once for all tests
func (s *ServiceSuite) SetupSuite() {
    // Expensive setup
    s.server = httptest.NewServer(testHandler)
    s.db = setupTestDatabase()
}

// TearDownSuite runs once after all tests
func (s *ServiceSuite) TearDownSuite() {
    s.server.Close()
    s.db.Close()
}

// SetupTest runs before each test
func (s *ServiceSuite) SetupTest() {
    s.tempDir, _ = os.MkdirTemp("", "test")
    s.svc = user.NewUserService(s.db, s.tempDir)
}

// TearDownTest runs after each test
func (s *ServiceSuite) TearDownTest() {
    os.RemoveAll(s.tempDir)
    // Clean DB state
}

// Tests
func (s *ServiceSuite) TestCreateUser() {
    // Use s.svc, s.db, s.server, s.tempDir
    err := s.svc.CreateUser(ctx, testUser)
    s.NoError(err)
}

func (s *ServiceSuite) TestGetUser() {
    // Shared setup from SetupTest
    user, err := s.svc.GetUser(ctx, testID)
    s.NoError(err)
    s.Equal("expected", user.Name)
}

// Run suite
func TestServiceSuite(t *testing.T) {
    suite.Run(t, new(ServiceSuite))
}
```

---

## Synchronization in Tests

### Never Use time.Sleep
Flaky tests, timing-dependent failures, slow tests.

### Use Channels
```go
func TestAsyncOperation(t *testing.T) {
    done := make(chan struct{})

    go func() {
        doAsyncWork()
        close(done)
    }()

    select {
    case <-done:
        // Success
    case <-time.After(1 * time.Second):
        t.Fatal("timeout waiting for async work")
    }
}

// With result
func TestAsyncWithResult(t *testing.T) {
    result := make(chan string, 1)

    go func() {
        result <- doWork()
    }()

    select {
    case r := <-result:
        assert.Equal(t, "expected", r)
    case <-time.After(1 * time.Second):
        t.Fatal("timeout")
    }
}
```

### Use WaitGroups
```go
func TestConcurrentOperations(t *testing.T) {
    var wg sync.WaitGroup
    results := make([]string, 10)

    for i := 0; i < 10; i++ {
        wg.Add(1)
        go func(index int) {
            defer wg.Done()
            results[index] = doWork(index)
        }(i)
    }

    wg.Wait()

    // Assert on results
    for _, r := range results {
        assert.NotEmpty(t, r)
    }
}
```

---

## Test Organization

### File Structure
```
user/
├── user.go
├── user_test.go          # Tests for user.go
├── service.go
├── service_test.go       # Tests for service.go
├── repository.go
└── repository_test.go    # Tests for repository.go
```

### Package Naming
```go
// ✅ External package - tests public API only
package user_test

import (
    "testing"
    "github.com/yourorg/project/user"
)

// ❌ Same package - can test private methods (don't do this)
package user

import "testing"
```

---

## Real Implementation Patterns

### Pattern 1: In-Memory Repository
```go
// user/inmem.go
package user

type InMemoryRepository struct {
    mu    sync.RWMutex
    users map[UserID]User
}

func NewInMemoryRepository() *InMemoryRepository {
    return &InMemoryRepository{
        users: make(map[UserID]User),
    }
}

func (r *InMemoryRepository) Save(ctx context.Context, u User) error {
    r.mu.Lock()
    defer r.mu.Unlock()
    r.users[u.ID] = u
    return nil
}

func (r *InMemoryRepository) Get(ctx context.Context, id UserID) (*User, error) {
    r.mu.RLock()
    defer r.mu.RUnlock()

    u, ok := r.users[id]
    if !ok {
        return nil, ErrNotFound
    }
    return &u, nil
}
```

### Pattern 2: Test Email Sender
```go
// user/test_emailer.go
package user

import (
    "bytes"
    "sync"
)

type TestEmailer struct {
    mu     sync.Mutex
    buffer bytes.Buffer
}

func NewTestEmailer() *TestEmailer {
    return &TestEmailer{}
}

func (e *TestEmailer) Send(to Email, subject, body string) error {
    e.mu.Lock()
    defer e.mu.Unlock()

    fmt.Fprintf(&e.buffer, "To: %s\nSubject: %s\n%s\n\n", to, subject, body)
    return nil
}

func (e *TestEmailer) SentEmails() string {
    e.mu.Lock()
    defer e.mu.Unlock()
    return e.buffer.String()
}
```

### Pattern 3: HTTP Test Server
```go
func TestAPIClient(t *testing.T) {
    // Create test server
    server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Mock API response
        w.WriteHeader(http.StatusOK)
        json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
    }))
    defer server.Close()

    // Use real HTTP client with test server URL
    client := NewAPIClient(server.URL)
    result, err := client.GetStatus()

    assert.NoError(t, err)
    assert.Equal(t, "ok", result.Status)
}
```

---

## Testable Examples (GoDoc Examples)

### When to Add
- Non-trivial types
- Types with validation
- Common usage patterns
- Functions that benefit from example

### Pattern
```go
// Example_TypeName demonstrates basic usage.
func Example_UserID() {
    id, _ := user.NewUserID("usr_123")
    fmt.Println(id)
    // Output: usr_123
}

// Example_TypeName_validation shows validation behavior.
func Example_UserID_validation() {
    _, err := user.NewUserID("")
    fmt.Println(err != nil)
    // Output: true
}

// Example_TypeName_scenario shows specific use case.
func Example_UserService_CreateUser() {
    repo := user.NewInMemoryRepository()
    svc, _ := user.NewUserService(repo, nil)

    id, _ := user.NewUserID("usr_123")
    u := user.User{ID: id, Name: "Alice"}

    err := svc.CreateUser(context.Background(), u)
    fmt.Println(err == nil)
    // Output: true
}
```

### Guidelines
- Should be in test file (`*_test.go`)
- Use `pkg_test` package
- Show only happy path (no complex scenarios)
- No mocking
- Keep simple and focused
- Verify with `// Output:` comment

---

## Performance Testing

### Benchmark Tests
```go
func BenchmarkNewUserID(b *testing.B) {
    for i := 0; i < b.N; i++ {
        user.NewUserID("usr_123")
    }
}

func BenchmarkService_CreateUser(b *testing.B) {
    repo := user.NewInMemoryRepository()
    svc, _ := user.NewUserService(repo, nil)
    testUser := createTestUser()

    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        svc.CreateUser(context.Background(), testUser)
    }
}
```

---

## Testing Checklist

### Before Considering Tests Complete

**Structure:**
- [ ] Tests in `pkg_test` package
- [ ] Testing public API only
- [ ] Table-driven tests use named fields
- [ ] No conditionals in test cases

**Implementation:**
- [ ] Using real implementations, not mocks
- [ ] No time.Sleep (using channels/waitgroups)
- [ ] Testify suites only for complex setup

**Coverage:**
- [ ] Leaf types: 100% unit test coverage
- [ ] Orchestrating types: Integration tests
- [ ] Happy path covered
- [ ] Edge cases covered
- [ ] Error cases covered

**Examples:**
- [ ] Testable examples for complex types
- [ ] Examples are runnable
- [ ] Examples show common patterns

---

## Summary

**The Golden Rule**: Cyclomatic complexity = 1 in all test cases

**Test Structure Choices:**
- **Table-driven tests**: Simple, focused scenarios
- **Testify suites**: Complex infrastructure setup only

**Test Philosophy:**
- Test only public API (`pkg_test` package)
- Use real implementations, not mocks
- Leaf types: 100% coverage
- Orchestrating types: Integration tests

**Common Pitfalls to Avoid:**
- ❌ Testing private methods
- ❌ Heavy mocking
- ❌ time.Sleep in tests
- ❌ Conditionals in test cases
- ❌ Unnamed struct fields in table tests
