```typescript
// ❌ must replace the module — hoisted above every import, one value for the whole file
vi.mock('../config/env', () => ({ CONFIG: { natsUrl: 'wss://nats.test', natsToken: 'test-token' } }))

it('publishes the event', async () => {
  vi.stubEnv('VITE_API_BASE_URL', 'https://api.test') // ❌ too late: CONFIG was built at import time
  window.__RUNTIME_ENV__ = { ...window.__RUNTIME_ENV__, NATS_URL: 'wss://other.test' } // ❌ shared window, leaks into the next test

  // ❌ cannot run in parallel — every test touching CONFIG shares the one module instance
  // ❌ testing two URLs means vi.resetModules() and a dynamic import() per test
})
```

Inventory: `CONFIG.natsUrl`/`natsToken` in 12 locations, `CONFIG.apiBaseUrl`/`tenantId`
in 8 — 20 sideways accesses, zero modules testable without a `vi.mock` or a `window` write.
