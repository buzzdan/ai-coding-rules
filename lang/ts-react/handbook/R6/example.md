```tsx
// ❌ one production implementer; the interface and the context exist for the double in the test
export interface DeviceRepository {
  findLatest(id: DeviceId): Promise<Device>
}
export const DeviceRepositoryContext = createContext<DeviceRepository | undefined>(undefined)

// ❌ the same seam with no declaration to grep for
vi.mock('../hooks/useDevices', () => ({
  useDevices: () => ({ data: [device], isLoading: false }),
}))

// ✅ concrete dependency; the test wires the REAL hook over the REAL fetch, and MSW answers it
export async function fetchLatestDevice(client: ApiClient, id: DeviceId): Promise<Device> {
  return parseDevice(await client.get(`/devices/${id}`))
}

it('shows the latest device', async () => {
  server.use(http.get('/api/devices/:id', () => HttpResponse.json(deviceFixture)))

  renderWithProviders(<DevicesPage />)

  expect(await screen.findByRole('heading', { name: deviceFixture.hostname })).toBeInTheDocument()
})
```

> **In TypeScript (opinionated):** `vi.mock` of a hook or service you own, and a
> `vi.fn()` object shaped like a service, are this smell with no `interface` to point
> at; an interface with one implementation injected through context "for testing" is
> the same finding. MSW is the real layer for HTTP: one handler file per API domain,
> started once in setup. Mocking the true boundary is fine: the router, the auth SDK,
> the clock (`vi.useFakeTimers`), `matchMedia`. A TypeScript `interface` is
> structural, so the one-implementer test transfers unchanged.
