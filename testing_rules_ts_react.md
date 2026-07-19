# Testing Rules — TypeScript & React

Companion to `coding_rules_ts_react.md`. Defines the testing strategy, tooling, and patterns for React frontends.

## Philosophy

Tests verify **behavior**, not implementation. We test what the user sees and does — clicks, text on screen, navigation — not internal state, CSS classes, or component internals.

**Core principles:**
- **MSW over vi.mock for HTTP** — API calls go through MSW, not manually mocked service functions
- **Real providers, real routing** — tests wrap components in the same providers production uses
- **No in-memory mocks for data fetching** — React Query talks to MSW, not fake return values
- **Integration tests for pages/tabs** — a page test renders the full component tree, not individual pieces
- **Unit tests for leaf logic** — pure calculations, custom hooks, and utility functions

## Stack

| Tool | Purpose |
|------|---------|
| Vitest | Test runner, assertions, module mocking |
| happy-dom | DOM environment (lighter than jsdom) |
| @testing-library/react | Component rendering + queries |
| @testing-library/user-event | Realistic user interactions |
| @testing-library/jest-dom | DOM matchers (`toBeInTheDocument`, etc.) |
| MSW v2 (`msw/node`) | HTTP request interception |

## Project Structure

```
src/
├── test-utils/
│   ├── setup.ts                    # Global: MSW lifecycle + jest-dom matchers
│   ├── testUtils.tsx               # Shared render helpers + factories
│   └── mocks/
│       ├── server.ts               # MSW server instance
│       └── handlers/
│           ├── index.ts            # Aggregates all handlers + re-exports mockData
│           ├── constants.ts        # API_BASE, TEST_SERVICE_ID, time offsets
│           ├── alerts.ts           # One file per API domain
│           ├── services.ts
│           └── ...
├── components/
│   └── Button/
│       ├── Button.tsx
│       └── Button.test.tsx         # Colocated unit test
├── pages/
│   └── ServiceView/tabs/Events/
│       ├── AlertsAndEventsTab.tsx
│       └── AlertsAndEventsTab.test.tsx  # Colocated integration test
└── hooks/
    ├── useFeature.ts
    └── useFeature.test.tsx         # Colocated hook test
```

**Rules:**
- Test files live next to the code they test: `Component.test.tsx` beside `Component.tsx`
- All test infrastructure lives in `src/test-utils/`
- MSW handlers are organized one file per API domain

## Global Test Setup

`src/test-utils/setup.ts` runs before every test file:

```ts
import * as matchers from '@testing-library/jest-dom/matchers'
import { cleanup } from '@testing-library/react'
import { afterAll, afterEach, beforeAll, expect } from 'vitest'
import { server } from './mocks/server'

expect.extend(matchers)

beforeAll(() => server.listen({ onUnhandledRequest: 'warn' }))
afterEach(() => {
  server.resetHandlers()
  cleanup()
})
afterAll(() => server.close())
```

Reference this in `vitest.config.ts`:

```ts
export default defineConfig({
  test: {
    globals: true,
    environment: 'happy-dom',
    setupFiles: './src/test-utils/setup.ts',
  }
})
```

## MSW Handler Patterns

Every API domain gets its own handler file following the **triple-export pattern**:

### 1. Mock data fixture

```ts
// handlers/alerts.ts
export const mockAlerts = [
  {
    id: 1,
    title: 'High CPU Usage',
    severity: 'WARNING',
    // ... typed fields matching the API response shape
  },
  { id: 2, title: 'Service Unreachable', severity: 'CRITICAL' },
]
```

### 2. Default handler array (always-on)

```ts
const ALERTS_PATH = `${API_BASE}/services/:serviceId/alerts`

export const alertsHandlers = [
  http.get(ALERTS_PATH, () =>
    HttpResponse.json({
      data: mockAlerts,
      meta: { total: mockAlerts.length, has_next_page: false }
    })
  ),
]
```

### 3. Override handlers for specific scenarios

```ts
export const emptyAlertsHandler = http.get(ALERTS_PATH, () =>
  HttpResponse.json({ data: [], meta: { total: 0 } })
)

export const alertsErrorHandler = http.get(ALERTS_PATH, () =>
  HttpResponse.error()
)
```

### Aggregating handlers

`handlers/index.ts` combines all domain handlers and re-exports everything:

```ts
export const handlers = [
  ...alertsHandlers,
  ...servicesHandlers,
  ...eventsHandlers,
  // ...
]

// Re-export override handlers by name
export { emptyAlertsHandler, alertsErrorHandler }
export { emptyServicesHandler, servicesErrorHandler }

// Aggregate mock data for easy import in tests
export const mockData = {
  alerts: mockAlerts,
  services: mockServices,
  events: mockEvents,
}
```

### Advanced handler patterns

**Pagination:**
```ts
http.get(SERVICES_PATH, ({ request }) => {
  const url = new URL(request.url)
  const page = parseInt(url.searchParams.get('page') || '1', 10)
  const pageSize = parseInt(url.searchParams.get('page_size') || '16', 10)
  const start = (page - 1) * pageSize
  const results = mockServices.slice(start, start + pageSize)
  return HttpResponse.json({
    results,
    meta: { page, page_size: pageSize, total: mockServices.length }
  })
})
```

**Search / filtering:**
```ts
http.get(`${API_BASE}/channels/search`, ({ request }) => {
  const url = new URL(request.url)
  const query = url.searchParams.get('query')?.toLowerCase() ?? ''
  const filtered = mockChannels.filter((ch) =>
    ch.name?.toLowerCase().includes(query)
  )
  return HttpResponse.json(filtered)
})
```

**Stateful handlers** (mutations that update in-memory state):
```ts
let tokens: Token[] = [{ id: 'token-1', service_id: TEST_SERVICE_ID }]

export const resetMockTokens = () => {
  tokens = [{ id: 'token-1', service_id: TEST_SERVICE_ID }]
}

export const tokenHandlers = [
  http.get(TOKENS_PATH, () => HttpResponse.json(tokens)),
  http.post(TOKENS_PATH, async ({ request }) => {
    const body = await request.json()
    const newToken = { id: 'token-new', ...body }
    tokens.push(newToken)
    return HttpResponse.json(newToken, { status: 201 })
  }),
  http.delete(`${TOKENS_PATH}/:tokenId`, ({ params }) => {
    tokens = tokens.filter((t) => t.id !== params.tokenId)
    return new HttpResponse(null, { status: 204 })
  }),
]
```

Call `resetMockTokens()` in `beforeEach` when using stateful handlers.

## Test Utilities

### QueryClient factory

Every test gets a fresh QueryClient with retries disabled:

```ts
export const createTestQueryClient = () =>
  new QueryClient({ defaultOptions: { queries: { retry: false } } })
```

### renderWithProviders factory

A factory that returns a render function pre-configured with providers and routing:

```ts
export const createRenderWithProviders =
  (defaultPath: string) =>
  (ui: ReactElement, options: { route?: string; path?: string } = {}) => {
    const { route = defaultPath, path = defaultPath } = options
    const queryClient = createTestQueryClient()
    return {
      user: userEvent.setup(),
      ...render(
        <QueryClientProvider client={queryClient}>
          <MemoryRouter initialEntries={[route]}>
            <Routes>
              <Route element={ui} path={path} />
            </Routes>
          </MemoryRouter>
        </QueryClientProvider>
      ),
    }
  }
```

Each test file creates its own local version with the correct route:

```ts
const renderWithProviders = createRenderWithProviders(
  '/services/:serviceId/alertsEvents/:subTab?'
)
```

Or defines one inline if the shared factory doesn't fit:

```ts
const renderWithProviders = (ui: ReactElement, { route = '/default' } = {}) => {
  const queryClient = createTestQueryClient()
  return {
    user: userEvent.setup(),
    ...render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={[route]}>
          <Routes>
            <Route element={ui} path='/services/:serviceId/tab/:subTab?' />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    ),
  }
}
```

## Testing Layers

### Layer 1: Pure logic (no React)

For utility functions, calculations, transformers — no providers needed.

```ts
import { calculateUsage } from './usage'

describe('calculateUsage', () => {
  it('returns total from nested structure', () => {
    const result = calculateUsage(fixture)
    expect(result.total).toBe(42)
  })
})
```

### Layer 2: Unit tests for simple components

Components with no data fetching or routing. Minimal or no provider wrapping.

```ts
describe('Button', () => {
  it('calls onClick when clicked', async () => {
    const onClick = vi.fn()
    const user = userEvent.setup()
    render(<Button onClick={onClick}>Click me</Button>)

    await user.click(screen.getByRole('button', { name: /click me/i }))
    expect(onClick).toHaveBeenCalledOnce()
  })
})
```

### Layer 3: Hook tests

Use `renderHook` with a QueryClient wrapper. Service modules can be mocked with `vi.mock` when testing hook logic (caching, enabled flags, optimistic updates) in isolation.

```ts
const createWrapper = () => {
  const queryClient = createTestQueryClient()
  return ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  )
}

describe('useServiceStats', () => {
  it('fetches when enabled', async () => {
    const { result } = renderHook(
      () => useServiceStats({ serviceId: 's-1', enabled: true }),
      { wrapper: createWrapper() }
    )
    await waitFor(() => expect(result.current.isSuccess).toBe(true))
    expect(result.current.data).toEqual([mockToken])
  })

  it('skips fetch when disabled', () => {
    renderHook(
      () => useServiceStats({ serviceId: 's-1', enabled: false }),
      { wrapper: createWrapper() }
    )
    expect(mockFetchFn).not.toHaveBeenCalled()
  })
})
```

### Layer 4: Integration tests for pages and tabs

The most important layer. Renders the full component tree with real routing and MSW-backed data fetching.

```ts
describe('AlertsAndEventsTab', () => {
  // describe groups by concern
  describe('Rendering', () => {
    it('renders Alerts sub-tab by default', async () => {
      renderWithProviders(
        <AlertsAndEventsTab serviceId='test-service-id' />
      )
      await waitFor(() => {
        expect(screen.getByTestId('alerts-count'))
          .toHaveTextContent(`(${mockData.alerts.length})`)
      })
    })
  })

  describe('Empty States', () => {
    it('handles empty alerts gracefully', async () => {
      server.use(emptyAlertsHandler)  // override for this test only
      renderWithProviders(<AlertsAndEventsTab serviceId='test-service-id' />)
      await waitFor(() => {
        expect(screen.getByTestId('alerts-count')).toHaveTextContent('(0)')
      })
    })
  })

  describe('URL Routing', () => {
    it('renders events tab when URL has events subtab', async () => {
      renderWithProviders(
        <AlertsAndEventsTab serviceId='test-service-id' />,
        { route: '/services/test-service-id/alertsEvents/events' }
      )
      // assert events tab is active
    })
  })

  describe('User Interactions', () => {
    it('switches between tabs on click', async () => {
      const { user } = renderWithProviders(
        <AlertsAndEventsTab serviceId='test-service-id' />
      )
      await user.click(screen.getByRole('tab', { name: /events/i }))
      // assert tab switched
    })
  })
})
```

**Integration test describe groups:**

| Group | What it covers |
|-------|---------------|
| Rendering | All expected elements present after data loads |
| Loading State | Skeletons/spinners shown during fetch |
| Empty States | Behavior when API returns no data |
| Error States | Behavior when API returns errors |
| Data Display | Values from mockData shown correctly |
| User Interactions | Click, type, navigate |
| URL Routing | Component reads/writes URL params |

## Rules and Guidelines

### DO

- **Use MSW for all HTTP mocking** — handlers go in `test-utils/mocks/handlers/`
- **Use `server.use()` for test-specific overrides** — empty states, errors, edge cases
- **Assert against mockData** — `mockData.alerts.length`, not a hardcoded number
- **Use `waitFor` for async assertions** — data fetching is always async
- **Use `userEvent.setup()`** over `fireEvent` — more realistic event simulation
- **Query by role/label** — `getByRole('button', { name: /submit/i })` not `getByClassName`
- **Use `data-testid` sparingly** — only when semantic queries aren't possible
- **Group describes by concern** — Rendering, Empty States, URL Routing, User Interactions
- **Return `user` from renderWithProviders** — keeps event setup co-located with render

### DON'T

- **Don't mock service functions for component tests** — use MSW instead
- **Don't test internal state** — test what the user sees on screen
- **Don't hardcode counts** — reference `mockData.alerts.length`
- **Don't use `container.querySelector`** — use Testing Library queries
- **Don't use `fireEvent`** — use `userEvent` for realistic interactions
- **Don't share QueryClient between tests** — create a fresh one each time
- **Don't forget `retry: false`** — without it, failed queries retry and tests hang

### When vi.mock IS acceptable

`vi.mock` is reserved for dependencies that **cannot be intercepted via MSW**:

| Dependency | Why mock it |
|-----------|-------------|
| `@auth0/auth0-react` | Auth provider doesn't make real HTTP calls in tests |
| `react-router-dom` (partial) | To capture `useNavigate` calls via `mockNavigate` |
| Third-party UI libraries | When they have resolution issues in Vitest |
| Complex hook modules | When unit-testing a hook's caching/optimistic logic in isolation |

For everything else, prefer MSW.

### Auth0 mock pattern

Most test files need this at the top:

```ts
vi.mock('@auth0/auth0-react', () => ({
  useAuth0: () => ({
    isAuthenticated: true,
    isLoading: false,
    user: { email: 'test@example.com', sub: 'user-123' },
    logout: vi.fn(),
  }),
}))
```

Or import a shared config from test utils and spread it.

## Checklist — Before Submitting a Test

- [ ] MSW handlers exist for all API endpoints the component calls
- [ ] `retry: false` on the test QueryClient
- [ ] No `container.querySelector` — semantic queries only
- [ ] `userEvent.setup()` used, not `fireEvent`
- [ ] `waitFor` wraps all assertions that depend on async data
- [ ] Counts reference `mockData`, not hardcoded numbers
- [ ] Empty/error states tested via `server.use(override)`
- [ ] URL-driven behavior tested by passing different `route` options
- [ ] Describes grouped by concern (Rendering, Empty States, Interactions, etc.)
- [ ] No unnecessary `vi.mock` — MSW handles HTTP mocking
