# Testing Reference

The Testing Library and MSW catalogue behind the testing skill. The principles — test
the public API only, real implementations over mocks, 100% on leaf types, complexity 1
inside a test — are in the skill and in `../../rules/R7-test-placement.md`; this
file shows how each is spelled with Vitest, `@testing-library/react` and MSW v2.

## Contents

- [Parametrized tests](#parametrized-tests) — `it.each` with named rows, the success/error split
- [Rendering with providers](#rendering-with-providers) — `renderWithProviders`, a fresh `QueryClient`, `MemoryRouter`
- [Queries and user events](#queries-and-user-events) — role before label before text before test id; `userEvent.setup()`
- [MSW handlers and per-test overrides](#msw-handlers-and-per-test-overrides) — one file per API domain, `server.use`
- [Hooks](#hooks) — `renderHook` with the providers wrapper
- [Async and timers](#async-and-timers) — `findBy*`, `waitFor`, fake timers; never a `setTimeout` wait
- [Real implementations](#real-implementations) — an in-memory store, a recorded exchange, the true boundary
- [End-to-end](#end-to-end) — the repository's Playwright suite, run on request
- [Checklist](#checklist)

## Parametrized tests

`it.each` is the case table. Every row carries a `name`, so a failure names its
case; a row with more than two values is an object so each value has a name.
Success and error are two blocks: the error block's body is one `toThrow`, never
an `if (expectError)`.

```ts
describe('parsePolicy', () => {
  it.each([
    { name: 'plain', raw: '3x100ms', attempts: 3, delayMs: 100 },
  ])('parses $name', ({ raw, attempts, delayMs }) => {
    const policy = parsePolicy(raw)

    expect([policy.attempts, policy.delayMs]).toEqual([attempts, delayMs])
  })

  it.each([
    { name: 'zero attempts', raw: '0x100ms', message: /zero attempts/ },
    { name: 'missing delay', raw: '3x', message: /missing delay/ },
  ])('rejects $name', ({ raw, message }) => {
    expect(() => parsePolicy(raw)).toThrow(message)
  })
})
```

The canonical violation — one table with an `expectError` column and a branch on
it — and its split are in `../../rules/R7-test-placement.md`.

## Rendering with providers

A component that reads a query or the URL renders inside the providers production
gives it. `renderWithProviders` lives in `src/test-utils/` and builds a fresh
`QueryClient` per test — `retry: false`, or a failing query retries with backoff and
the test times out — plus a `MemoryRouter` at the route under test. It returns the
`userEvent` instance beside RTL's result so setup and interaction stay together.

```tsx
// src/test-utils/renderWithProviders.tsx
export function createTestQueryClient(): QueryClient {
  return new QueryClient({ defaultOptions: { queries: { retry: false } } })
}

export function renderWithProviders(
  ui: ReactElement,
  { route = '/', path = '/' }: Readonly<{ route?: string; path?: string }> = {},
): RenderResult & { user: UserEvent } {
  const user = userEvent.setup()
  const result = render(
    <QueryClientProvider client={createTestQueryClient()}>
      <MemoryRouter initialEntries={[route]}>
        <Routes>
          <Route element={ui} path={path} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>,
  )
  return { ...result, user }
}
```

A leaf component with no query and no route uses plain `render`; the wrapper is infrastructure, not a reflex.

## Queries and user events

Query the way a user finds the element: `getByRole` with an accessible name, then
`getByLabelText`, then `getByText`; `getByTestId` only where the markup carries no
role or text to find. `queryBy*` exists to assert absence; `findBy*` waits. Drive the
page with `userEvent`, which dispatches the event sequence a real pointer or keyboard
produces; `fireEvent` fires one synthetic event and skips focus, hover and `keydown`.

```tsx
it('saves the renamed device', async () => {
  const { user } = renderWithProviders(<DevicePage />, { route: '/devices/d-1', path: '/devices/:deviceId' })

  await user.clear(await screen.findByLabelText(/name/i))
  await user.type(screen.getByLabelText(/name/i), 'edge-02')
  await user.click(screen.getByRole('button', { name: /save/i }))

  expect(await screen.findByRole('status')).toHaveTextContent(/saved/i)
  expect(screen.queryByRole('alert')).not.toBeInTheDocument()
})
```

`toHaveBeenCalledTimes` belongs on a spy at the true boundary — a callback prop the
test passed in — never on a mocked internal module.

## MSW handlers and per-test overrides

MSW intercepts the real `fetch`, so `apiClient`, the service module and the query hook
all run their production code. `src/test-utils/setup.ts` calls `server.listen({
onUnhandledRequest: 'error' })` once per file, `server.resetHandlers()` and `cleanup()`
after every test, and `server.close()` at the end; each API domain has one handler file
exporting its default handlers and named overrides.

```ts
// src/test-utils/mocks/handlers/devices.ts
const DEVICES_PATH = `${API_BASE}/clusters/:clusterId/devices`

export const mockDevices = [
  { id: 'd-1', name: 'edge-01', status: 'READY' },
  { id: 'd-2', name: 'edge-02', status: 'DEGRADED' },
] as const

export const devicesHandlers = [
  http.get(DEVICES_PATH, () => HttpResponse.json({ data: mockDevices })),
]

export const emptyDevicesHandler = http.get(DEVICES_PATH, () =>
  HttpResponse.json({ data: [] }),
)

export const devicesErrorHandler = http.get(DEVICES_PATH, () =>
  HttpResponse.json({ message: 'upstream unavailable' }, { status: 503 }),
)
```

A test that needs the empty or failing shape prepends its override before rendering
— `server.use(emptyDevicesHandler)` as the first line, then
`await screen.findByText(/no devices yet/i)` — and the reset in `afterEach` means the
override never leaks into the next test. Assert against `mockDevices.length`, not a
literal count, so the fixture and the assertion cannot drift apart.

## Hooks

A hook with no DOM is tested through `renderHook`; one that reads a query gets the
providers as `wrapper`, built once per test so the cache survives re-renders. The
assertion is on `result.current`, awaited through `waitFor`.

```tsx
function createWrapper() {
  const queryClient = createTestQueryClient()
  return function Wrapper({ children }: Readonly<{ children: ReactNode }>) {
    return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  }
}

it('loads the devices of the cluster', async () => {
  const { result } = renderHook(() => useDevices('c-1'), { wrapper: createWrapper() })

  await waitFor(() => expect(result.current.isSuccess).toBe(true))
  expect(result.current.data).toHaveLength(mockDevices.length)
})
```

A `vi.mock` of the service module under the hook is R6's single-implementer seam: the
handler file already gives the hook a real HTTP layer to run against.

## Async and timers

Never wait on `setTimeout` in a test. Every wait has a subject and a timeout: `findBy*`
and `waitFor` poll the DOM until the assertion passes or RTL's timeout fails the test.
Code that itself schedules time — a debounce, a poll, a retry backoff — runs under fake
timers (`vi.useFakeTimers()` in `beforeEach`, `vi.useRealTimers()` in `afterEach`)
that the test advances explicitly.

```tsx
it('settles after the delay', async () => {
  const { result, rerender } = renderHook(({ value }) => useDebouncedValue(value, 300), {
    initialProps: { value: 'a' },
  })

  rerender({ value: 'ab' })
  await act(() => vi.advanceTimersByTimeAsync(300))

  expect(result.current).toBe('ab')
})
```

- `act` only around what RTL does not already wrap: advancing fake timers, a manual
  store update; `render`, `rerender`, `userEvent` and `waitFor` wrap themselves.
- `userEvent.setup({ advanceTimers: vi.advanceTimersByTime })` when fake timers and
  user events meet in one test, or the typed keystrokes never resolve.

## Real implementations

**An in-memory store** has the production store's public methods and a `Map` inside
(`class MemoryPreferencesStore implements PreferencesStore` with `get(key): string |
undefined` and `set(key, value): void` over a `private readonly values = new Map()`).
It lives in `src/test-utils/`, has its own tests, and is what a provider or hook test
composes — never a `vi.mock` of the module that owns the real one.

**A recorded exchange** is a handler whose body is a response captured from the real
API (`mocks/fixtures/devices.json`), so the parser at the boundary runs against the
wire's real shape — the `null`s, the string-encoded numbers — not a hand-typed ideal.
The handler stays an MSW handler; only its body is recorded.

**Only the true boundary is mocked**: the auth SDK (`vi.mock('@auth0/auth0-react',
...)`), `matchMedia`, `ResizeObserver`, the clock. The router is a real
`MemoryRouter`, the query client is real, `apiClient` is real and talks to MSW.

## End-to-end

End-to-end tests live under `e2e/` (or `tests/`) at the repository root and drive the
built app in a browser through the repository's Playwright (or Cypress) config, never
through Vitest. `webServer` in `playwright.config.ts` starts the app and the API and
polls their `url` until they answer; a fixed sleep is never the wait. The suite runs on
request (`npx playwright test`); the skill does not write a new e2e test by default —
a behavior goes to the lowest rung that contains it. Real external services come
last: `testcontainers` starts the API's database in Docker from the run when a routed
or recorded API cannot represent the behavior under test.

## Checklist

- [ ] Imports the module as a consumer would; no helper exported for the test
- [ ] `name` on every `it.each` row; object rows past two values
- [ ] Success and error in separate `it`s; no conditional in a body
- [ ] `renderWithProviders` only where a query or route is read; `retry: false`
- [ ] Role, label, text, then test id; `userEvent.setup()`, never `fireEvent`
- [ ] HTTP through MSW handlers; no `vi.mock` of an internal hook or service
- [ ] Every wait is `findBy*`, `waitFor` or an advanced fake timer; `vi.useRealTimers()` after
- [ ] `npx vitest run --coverage` shows 100% on leaf types
