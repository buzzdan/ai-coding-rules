```typescript
// ✅ clean class with injected dependencies
export class NATSClient {
  private readonly config: NatsConfig // injected, not global
  constructor(private readonly socket: NatsSocket, config: NatsConfig) {
    this.config = parseNatsConfig(config) // validated once, trusted thereafter — R2
  }

  async publishEvent(event: LiveEvent): Promise<void> {
    await this.socket.connect(this.config.url, this.config.token) // uses the injected value
    try {
      this.socket.publish(event.topic, JSON.stringify(event.payload))
    } finally {
      this.socket.close()
    }
  }
}
```

Island #1 is done: `NATSClient` is 100% testable with no globals in sight — it imports
nothing from `src/config/`; the socket arrives the same way the config does.
