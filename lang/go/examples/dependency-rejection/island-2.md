`messaging` no longer reads the global — its callers now face the dependency. Apply
the same move to them:

```go
// ✅ OrderService receives its dependencies
package order

type OrderService struct {
    dbHost     string       // injected
    natsClient *NATSClient  // clean dependency
}

func NewOrderService(dbHost string, natsClient *NATSClient) *OrderService {
    return &OrderService{dbHost: dbHost, natsClient: natsClient}
}

func (s *OrderService) ProcessOrder(orderID string) error {
    db := connectDB(s.dbHost)
    defer db.Close()

    return s.natsClient.PublishEvent(orderCreatedEvent)
}
```

Island #2. The globals have moved up one level — they are now read by whoever
constructs `OrderService`.
