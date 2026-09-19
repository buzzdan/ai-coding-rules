```go
// ✅ the global is read ONLY here, at wiring time
package api

type OrderHandler struct {
    orderService *OrderService
}

func SetupOrderHandler() *OrderHandler {
    natsClient := NewNATSClient(env.Configs.NATsAddress)
    orderService := NewOrderService(env.Configs.DBHost, natsClient)
    return &OrderHandler{orderService: orderService}
}

func (h *OrderHandler) HandleCreateOrder(w http.ResponseWriter, r *http.Request) {
    err := h.orderService.ProcessOrder(orderID) // all clean code from here down
    // ...
}
```

Final state: 2 global accesses (both in setup functions), down from 20. Everything
below the handlers is constructor-injected.
