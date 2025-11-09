# JSON-RPC Server Mock with DSL

## When to Use This Example

Use this when:
- Testing JSON-RPC clients
- Need to mock JSON-RPC server responses
- Want configurable mock behavior per method
- Need to track and assert on received requests
- Testing with OpenTelemetry trace propagation

**Dependency Level**: Level 1 (In-Memory) - Uses `httptest.Server` for in-memory HTTP

**Key Insight**: When testing a **JSON-RPC client**, mock the **server** it calls. Use rich DSL for readable test setup.

## Implementation

### Rich JSON-RPC Server Mock

```go
// internal/testutils/jrpc_server_mock.go
package testutils

import (
    "errors"
    "fmt"
    "net/http"
    "net/http/httptest"

    "github.com/gorilla/rpc/v2/json2"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/propagation"
    "go.opentelemetry.io/otel/trace"
)

var ErrMethodNotFound = errors.New("method not found")

// TraceQuery holds received JSON-RPC queries for assertions
type TraceQuery struct {
    Method string
    Params string
}

// JrpcTraceServerMock is a rich JSON-RPC server mock with DSL.
// Uses httptest.Server for in-memory HTTP (Level 1).
type JrpcTraceServerMock struct {
    tracer          trace.Tracer
    server          *httptest.Server
    mockResponses   map[string]any    // method -> response
    queriesReceived []TraceQuery      // for assertions
}

// StartJrpcTraceServerMock starts an in-memory JSON-RPC server.
// Returns a rich DSL object for configuring mock responses.
func StartJrpcTraceServerMock() *JrpcTraceServerMock {
    mock := &JrpcTraceServerMock{
        mockResponses: make(map[string]any),
        tracer:        otel.Tracer("trace-server-mock"),
    }

    mux := mock.createHTTPHandlers()
    mock.server = httptest.NewServer(mux)

    return mock
}

// AddMockResponse configures the mock to return a response for a method.
// This is the DSL - chain multiple calls for different methods!
func (m *JrpcTraceServerMock) AddMockResponse(method string, response any) {
    m.mockResponses[method] = response
}

// GetQueriesReceived returns all queries received (for assertions)
func (m *JrpcTraceServerMock) GetQueriesReceived() []TraceQuery {
    return m.queriesReceived
}

// Close shuts down the server (idempotent)
func (m *JrpcTraceServerMock) Close() {
    m.server.Close()
}

// Address returns the server address (for client configuration)
func (m *JrpcTraceServerMock) Address() string {
    return m.server.Listener.Addr().String()
}

func (m *JrpcTraceServerMock) createHTTPHandlers() *http.ServeMux {
    mux := http.NewServeMux()
    codec := json2.NewCodec()

    mux.HandleFunc("/reader", func(w http.ResponseWriter, r *http.Request) {
        // Extract OpenTelemetry context for realistic testing
        reqCtx := r.Context()
        reqCtx = otel.GetTextMapPropagator().Extract(reqCtx, propagation.HeaderCarrier(r.Header))
        reqCtx, span := m.tracer.Start(reqCtx, "jrpc-trace-server",
            trace.WithSpanKind(trace.SpanKindServer))
        defer span.End()

        if r.Method != http.MethodPost {
            w.WriteHeader(http.StatusMethodNotAllowed)
            return
        }

        receivedReq := codec.NewRequest(r)
        method, err := receivedReq.Method()
        if err != nil {
            w.WriteHeader(http.StatusBadRequest)
            return
        }

        // Check if we have a mock response configured
        if response, exists := m.mockResponses[method]; exists {
            args := struct{}{}
            if err := receivedReq.ReadRequest(&args); err != nil {
                receivedReq.WriteError(w, http.StatusBadRequest, err)
                return
            }

            // Store query for assertions
            m.queriesReceived = append(m.queriesReceived, TraceQuery{
                Method: method,
                Params: fmt.Sprintf("%+v", args),
            })

            // Write mock response
            receivedReq.WriteResponse(w, response)
            return
        }

        // Method not configured
        params := []string{}
        receivedReq.ReadRequest(&params)
        receivedReq.WriteError(w, http.StatusBadRequest, ErrMethodNotFound)
    })

    return mux
}
```

## Usage Examples

### Setup in Test Suite

```go
func (suite *TaskmonTestSuite) SetupSuite() {
    // Start in-memory JSON-RPC server mock (Level 1)
    suite.jrpcServerMock = testutils.StartJrpcTraceServerMock()

    // Configure mock responses using DSL
    suite.jrpcServerMock.AddMockResponse("protocol", struct {
        Version string `json:"version"`
        Date    string `json:"date"`
    }{
        Version: "3.18.0",
        Date:    "Sep-04-2018",
    })

    suite.jrpcServerMock.AddMockResponse("get_traces", struct {
        Traces []string `json:"traces"`
    }{
        Traces: []string{"trace1", "trace2"},
    })

    // Configure your client to use the mock server
    client := jrpc.NewClient(suite.jrpcServerMock.Address() + "/reader")
}

func (suite *TaskmonTestSuite) TearDownSuite() {
    suite.jrpcServerMock.Close()
}
```

### Test with Assertions

```go
func (suite *TaskmonTestSuite) TestProtocolVersion() {
    // Call your code that makes JSON-RPC requests
    version, err := suite.taskmon.GetProtocolVersion()
    suite.Require().NoError(err)
    suite.Equal("3.18.0", version.Version)

    // Assert on received queries
    queries := suite.jrpcServerMock.GetQueriesReceived()
    suite.Require().Len(queries, 1)
    suite.Equal("protocol", queries[0].Method)
}

func (suite *TaskmonTestSuite) TestGetTraces() {
    // Call your code
    traces, err := suite.taskmon.GetTraces()
    suite.Require().NoError(err)
    suite.Equal([]string{"trace1", "trace2"}, traces)

    // Verify the right method was called
    queries := suite.jrpcServerMock.GetQueriesReceived()
    suite.Require().Len(queries, 2) // protocol + get_traces
    suite.Equal("get_traces", queries[1].Method)
}
```

## Why This Pattern is Excellent

1. **Rich DSL** - `AddMockResponse()` for easy, readable configuration
2. **Readable Setup** - Tests are self-documenting, clear intent
3. **In-Memory** - Uses `httptest.Server` (Level 1, no network I/O)
4. **Query Tracking** - `GetQueriesReceived()` for assertions on what was called
5. **OpenTelemetry Integration** - Realistic trace propagation for observability testing
6. **Idempotent Cleanup** - Safe to call `Close()` multiple times
7. **Flexible** - Configure any method/response combination dynamically

## Key Design Principles

### DSL for Configuration

Mock setup should read like configuration:
```go
mock.AddMockResponse("method_name", expectedResponse)
mock.AddMockResponse("another_method", anotherResponse)
```

### Query Tracking for Assertions

Always track what was received:
- Method names called
- Parameters passed
- Order of calls
- Number of calls

### Built on httptest.Server

httptest.Server provides:
- In-memory HTTP (no network I/O)
- Automatic address allocation
- Clean lifecycle management
- Standard library, no dependencies

## Pattern Comparison

| Pattern | Use When |
|---------|----------|
| **httptest.Server** | Simple HTTP mocking |
| **NATS test harness** | Need real NATS (pub/sub) |
| **gRPC client mock** | Testing gRPC **server** |
| **JSON-RPC server mock** | Testing JSON-RPC **client** |

## Benefits

- **In-Memory** - No network I/O, pure Go
- **Fast** - Microsecond startup time
- **Configurable** - Dynamic response configuration per test
- **Trackable** - Full visibility into received requests
- **OpenTelemetry-aware** - Realistic trace propagation
- **Reusable** - Same infrastructure across test levels

## Key Takeaways

1. **Mock servers should have rich DSL** - Makes setup readable
2. **Track received requests** - Essential for assertions
3. **Use httptest.Server** - Perfect for HTTP-based protocols
4. **Make setup read like configuration** - Self-documenting tests
5. **Support trace propagation** - Realistic observability testing
6. **Idempotent cleanup** - Safe resource management
