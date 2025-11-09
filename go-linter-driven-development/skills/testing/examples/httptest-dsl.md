# HTTP Test Server with DSL Pattern

## When to Use This Example

Use this when:
- Testing HTTP clients or APIs
- Need simple, readable HTTP mocking
- Want to avoid complex mock frameworks
- Testing REST APIs, webhooks, or HTTP integrations

**Dependency Level**: Level 1 (In-Memory) - Uses stdlib `httptest.Server`

## Basic httptest.Server Pattern

### Simple HTTP Mock

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

## DSL Pattern for Readable Tests

### Without DSL (Verbose)

```go
func TestUserAPI(t *testing.T) {
    handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if r.Method == "GET" && r.URL.Path == "/users/1" {
            w.WriteHeader(200)
            json.NewEncoder(w).Encode(map[string]string{"id": "1", "name": "Alice"})
        } else if r.Method == "POST" && r.URL.Path == "/users" {
            // ... more complex logic
        } else {
            w.WriteHeader(404)
        }
    })
    server := httptest.NewServer(handler)
    defer server.Close()
    // ... test
}
```

### With DSL (Readable)

```go
func TestUserAPI(t *testing.T) {
    mockAPI := httpserver.New().
        OnGET("/users/1").
            RespondJSON(200, User{ID: "1", Name: "Alice"}).
        OnPOST("/users").
            WithBodyMatcher(hasRequiredFields).
            RespondJSON(201, User{ID: "2", Name: "Bob"}).
        Build()
    defer mockAPI.Close()

    // Test reads like documentation!
    client := NewAPIClient(mockAPI.URL())
    user, err := client.GetUser("1")
    // ... assertions
}
```

## Implementing the DSL

### Basic DSL Structure

```go
// internal/testutils/httpserver/server.go
package httpserver

import (
    "encoding/json"
    "net/http"
    "net/http/httptest"
)

type MockServer struct {
    routes  map[string]map[string]mockRoute // method -> path -> handler
    server  *httptest.Server
}

type mockRoute struct {
    statusCode int
    response   any
    matcher    func(*http.Request) bool
}

func New() *MockServerBuilder {
    return &MockServerBuilder{
        routes: make(map[string]map[string]mockRoute),
    }
}

type MockServerBuilder struct {
    routes map[string]map[string]mockRoute
}

func (b *MockServerBuilder) OnGET(path string) *RouteBuilder {
    return &RouteBuilder{
        builder: b,
        method:  "GET",
        path:    path,
    }
}

func (b *MockServerBuilder) OnPOST(path string) *RouteBuilder {
    return &RouteBuilder{
        builder: b,
        method:  "POST",
        path:    path,
    }
}

type RouteBuilder struct {
    builder    *MockServerBuilder
    method     string
    path       string
    statusCode int
    response   any
    matcher    func(*http.Request) bool
}

func (r *RouteBuilder) RespondJSON(statusCode int, response any) *MockServerBuilder {
    if r.builder.routes[r.method] == nil {
        r.builder.routes[r.method] = make(map[string]mockRoute)
    }
    r.builder.routes[r.method][r.path] = mockRoute{
        statusCode: statusCode,
        response:   response,
        matcher:    r.matcher,
    }
    return r.builder
}

func (r *RouteBuilder) WithBodyMatcher(matcher func(*http.Request) bool) *RouteBuilder {
    r.matcher = matcher
    return r
}

func (b *MockServerBuilder) Build() *MockServer {
    mock := &MockServer{routes: b.routes}

    handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        methodRoutes, ok := mock.routes[r.Method]
        if !ok {
            w.WriteHeader(http.StatusMethodNotAllowed)
            return
        }

        route, ok := methodRoutes[r.URL.Path]
        if !ok {
            w.WriteHeader(http.StatusNotFound)
            return
        }

        if route.matcher != nil && !route.matcher(r) {
            w.WriteHeader(http.StatusBadRequest)
            return
        }

        w.WriteHeader(route.statusCode)
        json.NewEncoder(w).Encode(route.response)
    })

    mock.server = httptest.NewServer(handler)
    return mock
}

func (m *MockServer) URL() string {
    return m.server.URL
}

func (m *MockServer) Close() {
    m.server.Close()
}
```

## Simple In-Memory Patterns

### In-Memory Repository

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

### Test Email Sender

```go
// user/test_emailer.go
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

## Benefits

- **Simple** - Built on stdlib, no external dependencies
- **Readable** - DSL makes tests self-documenting
- **Fast** - In-memory, microsecond startup
- **Flexible** - Easy to extend with new methods
- **Reusable** - Same pattern for all HTTP testing

## Key Takeaways

1. **Start with httptest.Server** - Simple and powerful
2. **Add DSL for readability** - When tests get complex
3. **Keep implementations simple** - In-memory maps, buffers
4. **Thread-safe** - Use mutexes for concurrent access
5. **Test your test infrastructure** - It's production code
