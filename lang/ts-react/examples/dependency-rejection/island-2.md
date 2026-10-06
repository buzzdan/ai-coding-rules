`natsClient` no longer reads the global — its callers now face the dependency. Apply
the same move to them:

```typescript
// ✅ OrderService receives its dependencies
export class OrderService {
  constructor(
    private readonly natsClient: NATSClient, // clean dependency
    private readonly baseUrl: string, // injected
  ) {}

  async processOrder(orderId: string): Promise<void> {
    await apiClient.post(`${this.baseUrl}/orders/${orderId}/process`)
    await this.natsClient.publishEvent(orderCreatedEvent)
  }
}
```

Island #2. The globals have moved up one level — they are now read by whoever
constructs `OrderService`.
