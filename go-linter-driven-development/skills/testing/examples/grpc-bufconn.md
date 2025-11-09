# gRPC Testing with bufconn and Rich Client Mocks

## When to Use This Example

Use this when:
- Testing gRPC servers
- Need bidirectional streaming tests
- Want in-memory gRPC (no network I/O)
- Testing server-client interactions
- Need rich DSL for readable tests

**Dependency Level**: Level 1 (In-Memory) - Uses `bufconn` for in-memory gRPC connections

**Key Insight**: When testing a **gRPC server**, mock the **clients** that connect to it. When testing a **gRPC client**, mock the **server**.

## Implementation

### Rich gRPC Client Mock with DSL

When your **System Under Test (SUT) is a gRPC server**, create rich client mocks:

```go
// internal/testutils/grpc_client_mock.go
package testutils

import (
    "context"
    "io"
    "sync"
    "testing"

    "github.com/stretchr/testify/require"
    "google.golang.org/grpc"
    "google.golang.org/grpc/metadata"

    pb "myproject/grpc_api/gen/go/traces/v1"
)

// TaskmonOnCluster is a rich gRPC client mock with DSL for testing gRPC servers.
// It connects to your gRPC server and provides helper methods for assertions.
type TaskmonOnCluster struct {
    clusterRoutingKey       string
    taskmonID               string
    stream                  pb.RemoteTracesService_StreamTracesClient
    mu                      sync.RWMutex
    receivedQuery           *pb.TracesQuery
    receivedQueriesPayloads []string
}

// OpenTaskmonToWekaHomeStream creates a gRPC client mock that connects to your server.
// This is the constructor for the mock - returns a rich DSL object.
func OpenTaskmonToWekaHomeStream(
    ctx context.Context,
    client pb.RemoteTracesServiceClient,
    clusterRoutingKey, taskmonID string,
) (*TaskmonOnCluster, error) {
    // Inject metadata (like session tokens) into context
    md := metadata.Pairs("X-Taskmon-session-token", clusterRoutingKey)
    ctx = metadata.NewOutgoingContext(ctx, md)

    // Open streaming connection to the server (your SUT)
    stream, err := client.StreamTraces(ctx, grpc.Header(&md))
    if err != nil {
        return nil, err
    }

    return &TaskmonOnCluster{
        stream:                  stream,
        clusterRoutingKey:       clusterRoutingKey,
        taskmonID:               taskmonID,
        receivedQueriesPayloads: []string{},
    }, nil
}

// SessionToken returns the session token (useful for assertions)
func (m *TaskmonOnCluster) SessionToken() string {
    return m.clusterRoutingKey
}

// Close closes the stream (idempotent)
func (m *TaskmonOnCluster) Close() {
    if m.stream == nil {
        return
    }
    m.stream.CloseSend()
}

// ListenToStreamAndAssert is a helper that listens to server messages and asserts.
// This makes tests read like documentation!
func (m *TaskmonOnCluster) ListenToStreamAndAssert(
    t *testing.T,
    expectedQueryPayload,
    resultPayload string,
) {
    for {
        query, err := m.stream.Recv()
        if err == io.EOF {
            break
        }
        require.NoError(t, err, "Failed to receive query from server")

        // Store received data (thread-safe)
        m.mu.Lock()
        m.receivedQuery = query
        m.receivedQueriesPayloads = append(m.receivedQueriesPayloads, string(query.TracesQueryPayload))
        m.mu.Unlock()

        // Assert expected payload
        require.Equal(t, expectedQueryPayload, string(query.TracesQueryPayload))

        // Send response back to server
        response := &pb.TracesFromServer{
            TraceServerRoute: query.TraceServerRoute,
            TracesPayload:    []byte(resultPayload),
            MessageId:        query.MessageId,
        }
        err = m.stream.Send(response)
        require.NoError(t, err, "Failed to send response")
    }
}

// LastReceivedQuery returns the last received query (thread-safe)
func (m *TaskmonOnCluster) LastReceivedQuery() *pb.TracesQuery {
    m.mu.RLock()
    defer m.mu.RUnlock()
    return m.receivedQuery
}

// ReceivedQueriesPayloads returns all received payloads (thread-safe)
func (m *TaskmonOnCluster) ReceivedQueriesPayloads() []string {
    m.mu.RLock()
    defer m.mu.RUnlock()
    return m.receivedQueriesPayloads
}
```

## Usage in Integration Tests

### Complete Test Suite Example

```go
//go:build integration

package integration_test

import (
    "context"
    "net"
    "testing"
    "time"

    "github.com/stretchr/testify/suite"
    "google.golang.org/grpc"
    "google.golang.org/grpc/credentials/insecure"
    "google.golang.org/grpc/test/bufconn"

    pb "myproject/grpc_api/gen/go/traces/v1"
    "myproject/internal/remotetraces"
    "myproject/internal/testutils"
)

type RemoteTracesTestSuite struct {
    suite.Suite
    lis        *bufconn.Listener  // In-memory gRPC connection
    ctx        context.Context
    natsServer *nserver.Server     // In-memory NATS
}

func (suite *RemoteTracesTestSuite) SetupSuite() {
    suite.ctx = context.Background()

    // Start in-memory NATS server (Level 1)
    natsServer, err := testutils.RunNATsServer()
    suite.Require().NoError(err)
    suite.natsServer = natsServer

    // Connect to NATS
    natsAddress := "nats://" + natsServer.Addr().String()
    nc, err := natsremotetraces.ConnectToRemoteTracesSession(suite.ctx, natsAddress, 2, 2, 10)
    suite.Require().NoError(err)

    // ** System Under Test: gRPC Server **
    // Use bufconn for in-memory gRPC (no network I/O!)
    suite.lis = bufconn.Listen(1024 * 1024)
    s := grpc.NewServer()

    // Your gRPC server implementation
    remoteTracesServer := remotetraces.NewGRPCServer(nc, 10, 10, time.Second)
    pb.RegisterRemoteTracesServiceServer(s, remoteTracesServer)

    go func() {
        if err := s.Serve(suite.lis); err != nil {
            suite.NoError(err)
        }
    }()
}

func (suite *RemoteTracesTestSuite) bufDialer(ctx context.Context, _ string) (net.Conn, error) {
    return suite.lis.DialContext(ctx)
}

func (suite *RemoteTracesTestSuite) TestStreamTraces() {
    // Create gRPC client (connects to your server)
    conn, err := grpc.NewClient("passthrough:///bufnet",
        grpc.WithContextDialer(suite.bufDialer),
        grpc.WithTransportCredentials(insecure.NewCredentials()),
    )
    suite.Require().NoError(err)
    defer conn.Close()

    client := pb.NewRemoteTracesServiceClient(conn)

    // Create rich gRPC client mock (testutils DSL!)
    clusterRoutingKey := "test-cluster-123"
    taskmonMock, err := testutils.OpenTaskmonToWekaHomeStream(
        suite.ctx, client, clusterRoutingKey, "taskmon-1")
    suite.Require().NoError(err)
    defer taskmonMock.Close()

    expectedQuery := "fetch_traces_query"
    expectedResult := "traces_result_data"

    // Start listening (this makes the test readable!)
    go taskmonMock.ListenToStreamAndAssert(suite.T(), expectedQuery, expectedResult)

    // Send query to server (via NATS or HTTP API)
    // ... your test logic here ...

    // Assert using helper methods
    suite.Eventually(func() bool {
        return taskmonMock.LastReceivedQuery() != nil &&
            string(taskmonMock.LastReceivedQuery().TracesQueryPayload) == expectedQuery
    }, 5*time.Second, 500*time.Millisecond)
}

func TestRemoteTracesTestSuite(t *testing.T) {
    suite.Run(t, new(RemoteTracesTestSuite))
}
```

## Why This Pattern is Excellent

1. **Rich DSL** - `OpenTaskmonToWekaHomeStream()` returns friendly object with helper methods
2. **Helper Methods** - `ListenToStreamAndAssert()`, `LastReceivedQuery()`, `ReceivedQueriesPayloads()`
3. **Thread-Safe** - Mutex protects shared state for concurrent access
4. **Readable Tests** - Tests read like documentation, clear intent
5. **In-Memory** - Uses `bufconn` (no network I/O, pure Go)
6. **Reusable** - Same mock for unit, integration, and system tests
7. **Event-Driven** - Can add channels for connection events if needed

## Key Design Principles

### Testing Direction

- **Testing a server?** → Mock the **clients** that connect to it
- **Testing a client?** → Mock the **server** it connects to

### DSL Benefits

- Use rich DSL objects with helper methods
- Make tests read like documentation
- Hide complexity behind clean interfaces
- Provide thread-safe state tracking
- Enable fluent assertions

### In-Memory with bufconn

`bufconn` provides an in-memory, full-duplex network connection:
- No network I/O overhead
- No port allocation needed
- Faster than TCP loopback
- Perfect for CI/CD
- Deterministic behavior

## Benefits

- **No Docker required** - Pure Go, works anywhere
- **No binary downloads** - Everything in-memory
- **No network I/O** - Unless testing actual network code
- **Perfect for CI/CD** - Fast, reliable, no external dependencies
- **Lightning fast** - Microsecond startup time
- **Thread-safe** - Concurrent test execution safe

## Alternative: Testing gRPC Clients

If you're testing a **gRPC client**, mock the **server** instead:

```go
// internal/testutils/grpc_server_mock.go
type MockGRPCServer struct {
    pb.UnimplementedRemoteTracesServiceServer
    mu              sync.Mutex
    receivedQueries []*pb.TracesQuery
}

func (m *MockGRPCServer) StreamTraces(stream pb.RemoteTracesService_StreamTracesServer) error {
    // Mock server implementation
    // Store received queries, send responses
    // ...
    return nil
}

// Usage
server := testutils.NewMockGRPCServer()
lis := bufconn.Listen(1024 * 1024)
s := grpc.NewServer()
pb.RegisterRemoteTracesServiceServer(s, server)
// ... test your client against this mock server
```

## Key Takeaways

1. **bufconn is Level 1** - In-memory, no external dependencies
2. **Mock the opposite end** - Server → mock clients, Client → mock server
3. **Rich DSL makes tests readable** - Helper methods, clear intent
4. **Thread-safe state tracking** - Use mutexes for concurrent access
5. **Reusable across test levels** - Same infrastructure everywhere
6. **Check for official test harnesses first** - Many libraries provide them (like NATS)
