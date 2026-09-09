Real refactoring — `env.Configs.NATsAddress` was read in 12 places deep in the
codebase.

### Before — sideways access

```go
package messaging

func PublishEvent(event Event) error {
    conn, err := nats.Connect(env.Configs.NATsAddress) // global reached from a leaf
    if err != nil {
        return fmt.Errorf("connect failed: %w", err)
    }
    defer conn.Close()
    // ...
}

// the test must mutate shared state — and cannot run in parallel
func TestPublishEvent(t *testing.T) {
    env.Configs.NATsAddress = "nats://test:4222" // leaks into every other test
    // ...
}
```

### After — dependency rejected upward, injected at the edge

```go
package messaging

type NATSClient struct {
    natsAddress string // injected, not global
}

func NewNATSClient(natsAddress string) *NATSClient {
    return &NATSClient{natsAddress: natsAddress}
}

func (c *NATSClient) PublishEvent(event Event) error {
    conn, err := nats.Connect(c.natsAddress)
    // ...
}

// package api — the global is read ONLY at the entry point
func SetupOrderHandler() *OrderHandler {
    natsClient := NewNATSClient(env.Configs.NATsAddress)
    orderService := NewOrderService(env.Configs.DBHost, natsClient)
    return &OrderHandler{orderService: orderService}
}
```

The test constructs a client against a local test NATS server — no global writes,
`t.Parallel()` works. The refactoring is incremental: one clean island at a time,
pushing the global up one level per iteration, from 20 scattered accesses down to 2
at the entry points. Full worked case — the dependency map, the island-by-island
progression, and the test payoff: `../examples/dependency-rejection.md`.
