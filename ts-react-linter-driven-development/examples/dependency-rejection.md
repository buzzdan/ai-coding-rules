# Dependency Rejection Case: Incremental Global Elimination

Demonstrates: R8

A real refactoring where a module-level `CONFIG` object (`src/config/env.ts`, built
from `import.meta.env` and `window.__RUNTIME_ENV__` at import time) reached from deep
inside the codebase (20+ access points) was eliminated incrementally — one clean
island at a time, pushing each global up one level per iteration until only the entry
point touched the environment. This is the case law for R8: the rejection move, why
sideways access resists testing, and the pragmatic stopping point.

This pattern differs from the other refactorings in one important way: it is **not a
one-time fix**. It is an incremental journey — start at the bottom (leaf code),
create one clean island at a time, push globals toward `main.tsx` and the provider
tree, and accept globals at the top.

## Which globals are the problem

Some globals are designed to be global and are fine: constants and `as const` enums,
types, pure functions, the `createContext` object (a key — the value lives in a
provider), styles. The problem is configuration and mutable state reached sideways:

- `CONFIG.natsUrl`, `CONFIG.apiBaseUrl`, `CONFIG.tenantId` — any `CONFIG.*` imported
  from `src/config/env.ts` into a service, a hook or a component, and any
  `import.meta.env` or `window.__RUNTIME_ENV__` read outside `main.tsx`.

Why these are defects: they make code untestable except by replacing shared state
(`vi.mock('../config/env')` and `vi.stubEnv` against a production module are the
evidence), create hidden dependencies invisible in any signature or props type,
forbid parallel tests, and weld every caller to one config object built when the
module first loads.

## Before — global chaos

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

And the testing nightmare the globals cause:

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

## Step 1 — map the dependency chain

```
main.tsx
  └─ <App /> routes and pages (entry points)
       ├─ useProcessOrder() → orderService.processOrder()   [USES CONFIG.apiBaseUrl]
       │    └─ natsClient.publishEvent()                    [USES CONFIG.natsUrl]
       │    └─ natsClient.publishBatch()                    [USES CONFIG.natsUrl]
       └─ useCreateUser() → userService.createUser()        [USES CONFIG.apiBaseUrl]
            └─ natsClient.publishEvent()                    [USES CONFIG.natsUrl]
```

The deepest usage — furthest from `main.tsx` — is `natsClient.publishEvent`/
`publishBatch`. **Start there.** Bottom-up matters: extracting the leaf first means
each iteration produces a finished, testable island; top-down — a `config` prop handed
down from `App` — would thread props through layers that still read the global
underneath.

## Step 2 — create the first clean island

The rejection move: the function stops *fetching* the value and starts *being given*
it — as a constructor-injected field on a new type.

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

## Step 3 — push the global up one level

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

## Step 4 — stop at the entry points

```tsx
// ✅ src/main.tsx — the environment is read ONLY here, at wiring time
const config = readAppConfig(import.meta.env, window.__RUNTIME_ENV__) // one AppConfig, validated once
const natsClient = new NATSClient(new WsSocket(), { url: config.natsUrl, token: config.natsToken })
const services: Services = {
  orders: new OrderService(natsClient, config.apiBaseUrl),
  users: new UserService(natsClient, config.apiBaseUrl),
}
createRoot(rootElement).render(<ServicesProvider value={services}><App /></ServicesProvider>)

// src/hooks/useServices.ts — the context is a key; the value is built once, above
const ServicesContext = createContext<Services | undefined>(undefined)
export const ServicesProvider = ServicesContext.Provider
export function useServices(): Services {
  const services = useContext(ServicesContext)
  if (services === undefined) throw new Error('useServices() outside <ServicesProvider>')
  return services
}
```

Final state: 2 environment reads — `main.tsx`, and `renderWithProviders` in
`src/test-utils/`, which wraps the same provider around page tests with defaults read
from `.env.test` — down from 20 sideways accesses. `src/config/env.ts` is deleted;
`useProcessOrder()` asks `useServices().orders`; everything below is constructor-injected.

## The test payoff

```tsx
// src/services/natsClient.test.ts
it('publishes the event over the socket', async () => {
  const socket = new FakeSocket() // ✅ a fake at the transport boundary, fake data — no shared state
  const client = new NATSClient(socket, { url: 'wss://nats.test', token: 'test-token' }) // clean injection
  await client.publishEvent(TEST_EVENT)
  expect(socket.published).toEqual([{ subject: TEST_EVENT.topic, data: JSON.stringify(TEST_EVENT.payload) }])
})

it('rejects when the socket refuses the connection', async () => {
  const client = new NATSClient(FakeSocket.refusing(), { url: 'wss://nonexistent:4222', token: 'test-token' })
  await expect(client.publishEvent(TEST_EVENT)).rejects.toThrow(ConnectionError)
})

// src/pages/Orders/OrdersPage.test.tsx — a page test supplies its own services
it('processes the selected order', async () => {
  const orders = new OrderService(new NATSClient(new FakeSocket(), TEST_NATS), 'https://api.test')
  renderWithProviders(<OrdersPage />, { services: { ...TEST_SERVICES, orders } })
  await userEvent.click(screen.getByRole('button', { name: 'Process' }))
  expect(await screen.findByText('Order processed')).toBeInTheDocument()
})
```

Contrast with the before-test: no `vi.mock`, no `vi.stubEnv`, no write to the shared
`window`, no ordering hazards, parallel by default under Vitest, and testing a second
URL is just constructing a second client. The stand-in is a `FakeSocket` at the
transport boundary — a fake in the legitimate sense (speaks the socket's contract,
records what it was given), not a `vi.mock` of the client module; the page test does
the same one level up, handing `ServicesProvider` its own services while MSW answers
the HTTP.

Testability before: 0 modules testable without a `vi.mock` or a `window` write,
parallel tests impossible. After: 3 clean islands (`NATSClient`, `OrderService`,
`UserService`), 100% coverage on them, fully parallel.

## Why sideways access resists testing

A global read is an input the test cannot supply through the code's own surface. To
control it, the test must write the shared variable — which serializes the whole
test binary around that variable, leaks values into unrelated tests, and still only
supports one value at a time. Constructor injection turns the same input into an
argument: each test builds its own instance, values never collide, and the
dependency is visible in the signature where reviewers and callers can see it.

## The incremental progression

```
Iteration 1: extract NATSClient        — global accesses 20 → 14, islands: 1
Iteration 2: extract OrderService      — global accesses 14 → 8,  islands: 2
Iteration 3: extract UserService       — global accesses 8 → 4,   islands: 3
Iteration 4: push to handler setup     — global accesses 4 → 2    ✅ done
```

Every iteration is a working, tested, deployable state. No big-bang refactoring —
if the work stops after iteration 2, the codebase is still strictly better than it
started.

## The decision points

1. **Bottom-up, not top-down.** Start at the deepest usage; each extraction is
   complete on its own. Top-down threading leaves half-injected layers that read
   globals underneath the new parameters.
2. **The endpoint is pragmatic, not zero.** Configuration at `main.tsx` and the
   provider at the root of the tree is acceptable — that is where it legitimately
   lives, read once from `import.meta.env` and `window.__RUNTIME_ENV__` into an
   `AppConfig`. Configuration in services, hooks and components is not. React context
   is the composition mechanism, not a second global: the provider sits at the root,
   the value is built once, consumers ask through `useServices()` and a test supplies
   its own. The goal is globals only where wiring happens.
3. **Don't "fix" the globals that aren't broken.** Constants, `as const` enums, types,
   pure functions, the `createContext` key and styles stay. Spending iterations
   pushing a constant through context is ceremony, not rejection.
4. **Rejection pairs with self-validation.** Once dependencies arrive through
   constructors, the constructor is the natural place to validate them
   (`../rules/R2-self-validating-types.md`) — the island trusts its fields
   thereafter.
