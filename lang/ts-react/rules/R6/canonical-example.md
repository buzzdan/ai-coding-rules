### Before — a seam exists only for a test double

```typescript
// deviceRepository.ts — one production implementation (ApiDeviceRepository); the
// interface and the context exist "so tests can swap it"
export interface DeviceRepository {
  findLatest(id: DeviceId): Promise<Device>
}

export const DeviceRepositoryContext = createContext<DeviceRepository | undefined>(undefined)

// DevicesPage.test.tsx — the ONLY other implementer is a hand-written double
class MockDeviceRepository implements DeviceRepository {
  constructor(private readonly device: Device) {}

  findLatest(): Promise<Device> {
    return Promise.resolve(this.device)
  }
}
```

The same seam without an interface, the React way — a module mock of the concrete
collaborator in a page test, while MSW handlers for the same endpoint already exist:

```typescript
vi.mock('../hooks/useDevices', () => ({ // ❌ the double rides in through the module
  useDevices: () => ({ data: [device], isLoading: false }),
}))
```

### After — concrete dependency, tested by wiring the real collaborator

```typescript
// devicesApi.ts — concrete; no cycle (apiClient does not import this module)
export async function fetchLatestDevice(id: DeviceId): Promise<Device> {
  return parseDevice(await apiClient.get(`/devices/${id}`))
}

// DevicesPage.test.tsx — the REAL hook over the REAL fetch; the MSW handler is the
// fake data
it('shows the latest device', async () => {
  server.use(http.get('/api/devices/:id', () => HttpResponse.json(deviceFixture)))

  renderWithProviders(<DevicesPage />) // real objects, fake data

  expect(await screen.findByRole('heading', { name: deviceFixture.hostname })).toBeInTheDocument()
})
```

The test now covers the seam it claims to cover: the real hook's query runs through
`apiClient` against a real `fetch`, and `parseDevice` sees the same wire shape
production does. The interface, the context, its indirection and the double are all
deleted; the `vi.mock` is gone with them. A TypeScript interface is structural, like
a Go interface, so the one-implementer smell transfers unchanged; `vi.mock` of an
internal hook or service and a `vi.fn()` object shaped like a service are the same
smell with no declaration to grep for. The earned interface, for contrast: a
`PreferencesStore` with two production implementations — one over `localStorage`
for the browser, one in memory for the embedded build that has no storage — where
the second implementer ships, and the test picks the in-memory one for the same
reason production does.
