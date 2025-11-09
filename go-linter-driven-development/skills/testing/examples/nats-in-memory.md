# NATS In-Memory Test Server

## When to Use This Example

Use this when:
- Testing message queue integrations with NATS
- Need pub/sub functionality in tests
- Want fast, in-memory NATS server (no Docker, no binary)
- Testing event-driven architectures

**Dependency Level**: Level 1 (In-Memory) - Pure Go, official test harness

## Implementation

### Setup Test Infrastructure

Many official SDKs provide test harnesses. Here's NATS:

```go
// internal/testutils/nats.go
package testutils

import (
    nserver "github.com/nats-io/nats-server/v2/server"
    natsserver "github.com/nats-io/nats-server/v2/test"
    "github.com/projectdiscovery/freeport"
)

// RunNATsServer runs a NATS server in-memory for testing.
// Uses the official NATS SDK test harness - no binary download needed!
func RunNATsServer() (*nserver.Server, error) {
    opts := natsserver.DefaultTestOptions

    // Allocate free port to prevent conflicts in parallel tests
    tcpPort, err := freeport.GetFreePort("127.0.0.1", freeport.TCP)
    if err != nil {
        return nil, err
    }

    opts.Port = tcpPort.Port

    // Start NATS server in-memory (pure Go!)
    return natsserver.RunServer(&opts), nil
}

// RunNATsServerWithJetStream runs NATS with JetStream enabled
func RunNATsServerWithJetStream() (*nserver.Server, error) {
    opts := natsserver.DefaultTestOptions

    tcpPort, err := freeport.GetFreePort("127.0.0.1", freeport.TCP)
    if err != nil {
        return nil, err
    }

    opts.Port = tcpPort.Port
    opts.JetStream = true

    return natsserver.RunServer(&opts), nil
}
```

## Usage in Integration Tests

### Basic Pub/Sub Test

```go
//go:build integration

package integration_test

import (
    "context"
    "testing"
    "time"
    "github.com/nats-io/nats.go"
    "github.com/stretchr/testify/require"
    "myproject/internal/testutils"
)

func TestNATSPubSub_Integration(t *testing.T) {
    // Start NATS server in-memory (Level 1 - pure Go!)
    natsServer, err := testutils.RunNATsServer()
    require.NoError(t, err)
    defer natsServer.Shutdown()

    // Connect to in-memory NATS
    natsAddress := "nats://" + natsServer.Addr().String()
    nc, err := nats.Connect(natsAddress)
    require.NoError(t, err)
    defer nc.Close()

    // Test pub/sub
    received := make(chan string, 1)
    _, err = nc.Subscribe("test.subject", func(msg *nats.Msg) {
        received <- string(msg.Data)
    })
    require.NoError(t, err)

    // Publish message
    err = nc.Publish("test.subject", []byte("hello"))
    require.NoError(t, err)

    // Wait for message
    select {
    case msg := <-received:
        require.Equal(t, "hello", msg)
    case <-time.After(1 * time.Second):
        t.Fatal("timeout waiting for message")
    }
}
```

### Real-World Usage Example (gRPC + NATS)

```go
// tests/gointegration/remote_traces_test.go
type RemoteTracesTestSuite struct {
    suite.Suite
    natsServer  *nserver.Server
    natsAddress string
    nc          *nats.Conn
    // ... other fields
}

func (suite *RemoteTracesTestSuite) SetupSuite() {
    // Start NATS server in-memory
    natsServer, err := testutils.RunNATsServer()
    suite.Require().NoError(err)

    suite.natsServer = natsServer
    suite.natsAddress = "nats://" + natsServer.Addr().String()

    // Connect application to in-memory NATS
    suite.nc, err = natsremotetraces.ConnectToRemoteTracesSession(
        suite.ctx, suite.natsAddress, numWorkers, numWorkers, channelSize)
    suite.Require().NoError(err)

    // Start gRPC server with NATS backend
    // ... rest of setup
}

func (suite *RemoteTracesTestSuite) TearDownSuite() {
    suite.nc.Close()
    suite.natsServer.Shutdown() // Clean shutdown
}

func (suite *RemoteTracesTestSuite) TestMessageFlow() {
    // Test your application logic that uses NATS
    // ...
}
```

## Why This is Excellent

- **Pure Go** - NATS server imported as library (no binary download)
- **Official** - Uses NATS SDK's official test harness
- **Fast** - Starts in microseconds
- **Reliable** - Same behavior as production NATS
- **Portable** - Works anywhere Go runs
- **No Docker** - No external dependencies
- **Parallel-Safe** - Free port allocation prevents conflicts

## Other Libraries with Test Harnesses

- **Redis**: `github.com/alicebob/miniredis` - Pure Go in-memory Redis
- **NATS**: `github.com/nats-io/nats-server/v2/test` (shown above)
- **PostgreSQL**: `github.com/jackc/pgx/v5/pgxpool` with pgx mock
- **MongoDB**: `github.com/tryvium-travels/memongo` - In-memory MongoDB

## Key Takeaways

1. **Check for official test harnesses first** - Many popular libraries provide them
2. **Use free port allocation** - Prevents conflicts in parallel tests
3. **Clean shutdown** - Always call `Shutdown()` in teardown
4. **Reusable infrastructure** - Same setup for unit, integration, and system tests
