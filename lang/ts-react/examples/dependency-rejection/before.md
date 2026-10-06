```typescript
// src/config/env.ts — global config built at import time, imported from every layer
export const CONFIG = {
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL,
  tenantId: window.__RUNTIME_ENV__.TENANT_ID,
  natsUrl: window.__RUNTIME_ENV__.NATS_URL,
  natsToken: window.__RUNTIME_ENV__.NATS_TOKEN,
}

// ❌ src/services/natsClient.ts — deep in the live-events code
export async function publishEvent(event: LiveEvent): Promise<void> {
  const socket = new WsSocket()
  await socket.connect(CONFIG.natsUrl, CONFIG.natsToken) // global reached from a leaf
  try {
    socket.publish(event.topic, JSON.stringify(event.payload))
  } finally {
    socket.close()
  }
}

// ❌ src/services/orderService.ts — more sideways access
export async function processOrder(orderId: string): Promise<void> {
  await apiClient.post(`${CONFIG.apiBaseUrl}/orders/${orderId}/process`)
  await publishEvent(orderCreatedEvent) // hides its NATS dependency
}
```
