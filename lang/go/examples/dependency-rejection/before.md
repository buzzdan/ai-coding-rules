```go
// Global config accessed everywhere
package env

var Configs struct {
    NATsAddress string
    DBHost      string
    RedisURL    string
}

// ❌ deep in the messaging code
package messaging

func PublishEvent(event Event) error {
    conn, err := nats.Connect(env.Configs.NATsAddress) // global reached from a leaf
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

// ❌ in the order service — more sideways access
package order

func ProcessOrder(orderID string) error {
    db := connectDB(env.Configs.DBHost)
    defer db.Close()

    return messaging.PublishEvent(orderCreatedEvent) // hides its NATS dependency
}
```
