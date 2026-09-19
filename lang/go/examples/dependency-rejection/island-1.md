```go
// ✅ clean type with injected dependency
type NATSClient struct {
    natsAddress string // injected, not global
}

func NewNATSClient(natsAddress string) *NATSClient {
    return &NATSClient{natsAddress: natsAddress}
}

func (c *NATSClient) PublishEvent(event Event) error {
    conn, err := nats.Connect(c.natsAddress) // uses the injected value
    if err != nil {
        return fmt.Errorf("connect failed: %w", err)
    }
    defer conn.Close()

    data, err := json.Marshal(event)
    if err != nil {
        return err
    }
    return conn.Publish(event.Topic, data)
}
```

Island #1 is done: `NATSClient` is 100% testable with no globals in sight.
