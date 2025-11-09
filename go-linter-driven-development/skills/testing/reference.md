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
    svc, _ := user.NewUserService(repo, notifier)
    err := svc.CreateUser(ctx, testUser)
    // ...
}
```

### 2. Avoid Mocks - Use Real Implementations

Instead of mocks, use:
- **HTTP test servers** (`httptest` package)
- **Temp files/directories** (`os.CreateTemp`, `os.MkdirTemp`)
- **In-memory databases** (SQLite in-memory, or custom implementations)
- **Test implementations** (TestEmailer that writes to buffer)

**Benefits:**
- Tests are more reliable
- Tests verify actual behavior
- Easier to maintain

### 3. Coverage Strategy

**Leaf Types** (self-contained):
- **Target**: 100% unit test coverage
- **Why**: Core logic must be bulletproof

**Orchestrating Types** (coordinate others):
- **Target**: Integration test coverage
- **Why**: Test seams between components

**Goal**: Most logic in leaf types (easier to test and maintain)

---

## Table-Driven Tests

### When to Use
- Each test case has **cyclomatic complexity = 1**
- No conditionals inside t.Run()
- Simple, focused testing scenarios

### ❌ Anti-Pattern: wantErr bool

**DO NOT** use `wantErr bool` pattern - it violates complexity = 1 rule:

```go
// ❌ BAD - Has conditionals (complexity > 1)
func TestNewUserID(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    UserID
        wantErr bool  // ❌ Anti-pattern
    }{
        {name: "valid ID", input: "usr_123", want: UserID("usr_123"), wantErr: false},
        {name: "empty ID", input: "", wantErr: true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := NewUserID(tt.input)
            if tt.wantErr {  // ❌ Conditional
                assert.Error(t, err)
                return
            }
            assert.NoError(t, err)
            assert.Equal(t, tt.want, got)
        })
    }
}
```

### ✅ Correct Pattern: Separate Functions

**Always separate success and error cases:**

```go
// ✅ Success cases - Complexity = 1
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
            require.NoError(t, err)  // ✅ No conditionals
            assert.Equal(t, tt.want, got)
        })
    }
}

// ✅ Error cases - Complexity = 1
func TestNewUserID_Error(t *testing.T) {
    tests := []struct {
        name  string
        input string
    }{
        {name: "empty ID", input: ""},
        {name: "whitespace only", input: "   "},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            _, err := NewUserID(tt.input)
            assert.Error(t, err)  // ✅ No conditionals
        })
    }
}
```

### Critical Rule: Named Struct Fields

**ALWAYS use named struct fields** - Linter reorders fields, breaking unnamed initialization:

```go
// ❌ BAD - Breaks when linter reorders fields
tests := []struct {
    name   string
    input  int
    want   string
}{
    {"test1", 42, "result"},  // Will break
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

---

## Testify Suites

### When to Use

ONLY for complex test infrastructure setup:
- Mock HTTP servers
- Database connections
- OpenTelemetry testing setup
- Temporary files/directories needing cleanup
- Shared expensive setup/teardown

### When NOT to Use
- Simple unit tests (use table-driven instead)
- Tests without complex setup

### Pattern

```go
package user_test

import (
    "net/http/httptest"
    "testing"
    "github.com/stretchr/testify/suite"
)

type ServiceSuite struct {
    suite.Suite
    server   *httptest.Server
    svc      *user.UserService
}

func (s *ServiceSuite) SetupSuite() {
    s.server = httptest.NewServer(testHandler)
}

func (s *ServiceSuite) TearDownSuite() {
    s.server.Close()
}

func (s *ServiceSuite) SetupTest() {
    s.svc = user.NewUserService(s.server.URL)
}

func (s *ServiceSuite) TestCreateUser() {
    err := s.svc.CreateUser(ctx, testUser)
    s.NoError(err)
}

func TestServiceSuite(t *testing.T) {
    suite.Run(t, new(ServiceSuite))
}
```

---

## Synchronization in Tests

### Never Use time.Sleep

Use channels or WaitGroups instead.

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
}
```

---

## Test Organization

### File Structure

```
user/
├── user.go
├── user_test.go          # Tests for user.go (pkg_test)
├── service.go
├── service_test.go       # Tests for service.go (pkg_test)
```

### Package Naming

```go
// ✅ External package - tests public API only
package user_test

import (
    "testing"
    "github.com/yourorg/project/user"
)
```

---

## Real Implementation Patterns

### In-Memory Repository

```go
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

### Test Email Sender

```go
package user

import (
    "bytes"
    "fmt"
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

---

## Testable Examples (GoDoc Examples)

### When to Add
- Non-trivial types
- Types with validation
- Common usage patterns

### Pattern

```go
// Example_UserID demonstrates basic usage.
func Example_UserID() {
    id, _ := user.NewUserID("usr_123")
    fmt.Println(id)
    // Output: usr_123
}

// Example_UserID_validation shows validation behavior.
func Example_UserID_validation() {
    _, err := user.NewUserID("")
    fmt.Println(err != nil)
    // Output: true
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
- [ ] Happy path, edge cases, error cases covered

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

---

# Example Files - Reusable Testing Patterns

The following example files contain **transferable patterns** that apply to many scenarios, not just the specific technologies shown. Claude should read these files based on the **pattern needed**, not the specific technology mentioned.

## Pattern 1: In-Memory Test Harness (Level 1)

**File**: `examples/nats-in-memory.md`

**Pattern**: Using official test harnesses from Go libraries

**When to read:**
- Need to test with ANY service that provides an official Go test harness
- Testing message queues, databases, caches, or any service with in-memory test mode
- Want to avoid Docker but need realistic service behavior

**Applies to:**
- **NATS** (shown in example) - Message queue with official test harness
- **Redis** - `github.com/alicebob/miniredis` pure Go in-memory Redis
- **MongoDB** - `github.com/tryvium-travels/memongo` in-memory MongoDB
- **PostgreSQL** - `github.com/jackc/pgx/v5` with pgx mock
- **Any Go library with test package** - Check if dependency has `/test` package

**Key techniques to adapt:**
- Wrapping official harness with clean API
- Free port allocation for parallel tests
- Clean lifecycle management (Setup/Teardown)
- Thread-safe initialization

---

## Pattern 2: Binary Dependency Management (Level 2)

**File**: `examples/victoria-metrics.md`

**Pattern**: Download, manage, and run ANY standalone binary for testing

**When to read:**
- Need to test against ANY external binary executable
- No in-memory option available
- Want production-like testing without Docker

**Applies to:**
- **Victoria Metrics** (shown in example) - Metrics database
- **Prometheus** - Metrics and alerting
- **Grafana** - Dashboards and visualization
- **Any database binaries** - PostgreSQL, MySQL, Redis, etc.
- **Any CLI tools** - Language servers, formatters, linters
- **Custom binaries** - Your own services or third-party tools

**Key techniques to adapt:**
- OS/ARCH detection (`runtime.GOOS`, `runtime.GOARCH`)
- Thread-safe binary downloads with double-check locking
- Health check polling with retries
- Graceful shutdown with `sync.Once`
- Free port allocation
- Temp directory management
- Version management via environment variables

---

## Pattern 3: Mock Server with Generic DSL (Level 1)

**File**: `examples/jsonrpc-mock.md`

**Pattern**: Building generic mock servers with configurable responses using `AddMockResponse()`

**When to read:**
- Need to mock ANY request/response protocol
- Want readable test setup with DSL
- Testing clients that call external APIs

**Applies to:**
- **JSON-RPC** (shown in example) - RPC over HTTP
- **REST APIs** - Use same pattern with route matching
- **GraphQL** - Configure response per query
- **gRPC** - Adapt for protobuf messages
- **WebSocket** - Mock message responses
- **Any HTTP-based protocol** - SOAP, XML-RPC, custom protocols

**Key techniques to adapt:**
- Generic `AddMockResponse(identifier, response)` pattern
- Using `httptest.Server` as foundation
- Query/request tracking for assertions
- Configuration-based response mapping
- Thread-safe response storage

---

## Pattern 4: Bidirectional Streaming with Rich DSL (Level 1)

**File**: `examples/grpc-bufconn.md`

**Pattern**: In-memory bidirectional communication with rich client/server mocks

**When to read:**
- Testing ANY bidirectional streaming protocol
- Need full-duplex communication in tests
- Want to avoid network I/O

**Applies to:**
- **gRPC** (shown in example) - Uses bufconn for in-memory
- **WebSockets** - Adapt bufconn pattern
- **TCP streams** - Custom protocols over TCP
- **Unix sockets** - Inter-process communication
- **Any streaming protocol** - Server-Sent Events, HTTP/2 streams

**Key techniques to adapt:**
- `bufconn` for in-memory connections (gRPC-specific, but concept applies)
- Rich mock objects with helper methods
- Thread-safe state tracking with mutexes
- Assertion helpers (`ListenToStreamAndAssert()`)
- When testing **server** → mock the **clients**
- When testing **client** → mock the **server**

---

## Pattern 5: HTTP DSL and Builder Pattern (Level 1)

**File**: `examples/httptest-dsl.md`

**Pattern**: Building readable test infrastructure with DSL wrappers over stdlib

**When to read:**
- Want to wrap ANY test infrastructure with clean DSL
- Need fluent, readable test setup
- Building reusable test utilities

**Applies to:**
- **HTTP mocking** (shown in example) - httptest.Server wrapper
- **Any test infrastructure** - Databases, queues, file systems
- **Test data builders** - Fluent APIs for creating test data
- **Custom test harnesses** - Wrapping complex setups

**Key techniques to adapt:**
- Builder pattern with method chaining
- Fluent API design (`OnGET().RespondJSON()`)
- Separating configuration from execution
- Type-safe builders with Go generics
- Hiding complexity behind clean interfaces

---

## Pattern 6: Test Organization and Structure

**File**: `examples/test-organization.md`

**When to read:**
- Setting up test structure for new projects
- Adding build tags for integration tests
- Configuring CI/CD for tests
- Creating testutils package structure

**Universal patterns** (not technology-specific):
- File organization (`pkg_test` package naming)
- Build tags (`//go:build integration`)
- Makefile/Taskfile structure
- CI/CD configuration
- testutils package layout

---

## Pattern 7: Integration Test Workflows

**File**: `examples/integration-patterns.md`

**When to read:**
- Testing component interactions across package boundaries
- Need patterns for Service + Repository testing
- Testing workflows that span multiple components

**Universal patterns:**
- Pattern 1: Service + Repository with in-memory deps
- Pattern 2: Testing with real external services
- Pattern 3: Multi-component workflow with testify suites
- Dependency priority (in-memory > binary > test-containers)

---

## Pattern 8: System Test (Black Box)

**File**: `examples/system-patterns.md`

**When to read:**
- Writing black-box end-to-end tests
- Testing via CLI or API
- Need tests that work without Docker

**Universal patterns:**
- CLI testing with `exec.Command`
- API testing with HTTP client
- Dependency injection architecture
- Pure Go testing (no Docker)

---

## How Claude Should Use These Files

### Pattern-Based Reading Rules

**When user needs to test with external dependencies:**

1. **Has official Go test harness?** → Read `nats-in-memory.md`
   - "Test with Redis/MongoDB/PostgreSQL/NATS"
   - "Avoid Docker but need real service"
   - Look for inspiration on wrapping official harnesses

2. **Need to download/run binary?** → Read `victoria-metrics.md`
   - "Test with Prometheus/Grafana/any binary"
   - "Manage binary dependencies"
   - Learn OS/ARCH detection, download patterns, health checks

3. **Need to mock request/response?** → Read `jsonrpc-mock.md`
   - "Mock REST/GraphQL/RPC/any HTTP API"
   - "Build mock with DSL"
   - Learn generic `AddMockResponse()` pattern

4. **Need bidirectional streaming?** → Read `grpc-bufconn.md`
   - "Test gRPC/WebSocket/streaming protocol"
   - "In-memory bidirectional communication"
   - Learn rich mock patterns, thread-safe state

5. **Want readable test DSL?** → Read `httptest-dsl.md`
   - "Build fluent test API"
   - "Wrap test infrastructure"
   - Learn builder pattern, method chaining

**When user asks about test structure:**
- "How should I organize tests?" → Read `test-organization.md`
- "How do I write integration tests?" → Read `integration-patterns.md`
- "How do I write system tests?" → Read `system-patterns.md`

### Key Principle

**Examples show specific technologies (NATS, Victoria Metrics, JSON-RPC) but teach transferable patterns.**

Claude should:
1. Identify the **pattern needed** (harness, binary, mock DSL, etc.)
2. Read the **example file** that demonstrates that pattern
3. **Adapt the techniques** to the user's specific technology
4. Use the example as a **template**, not a literal solution

### Default Behavior (No Example Needed)

For simple scenarios, use the core patterns in this file:
- Basic table-driven tests → Use patterns from this file
- Simple testify suites → Use patterns from this file
- Basic synchronization → Use patterns from this file
- Simple in-memory implementations → Use InMemoryRepository/TestEmailer from this file

**Read example files when patterns/techniques are needed, not just for specific tech.**

---

## Final Notes

This reference provides core testing principles and patterns. For detailed implementations and complete examples, refer to the example files listed above. Each example file is self-contained and can be read independently based on your testing needs.
