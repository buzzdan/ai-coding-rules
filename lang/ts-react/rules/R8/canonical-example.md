Real refactoring shape — `env.apiUrl` was read in 12 places deep in the codebase.

### Before — sideways access

```tsx
// src/config/env.ts — a module-level config object, read at import, from every layer
export const env = {
  apiUrl: window.__RUNTIME_ENV__.API_URL ?? import.meta.env.VITE_API_URL,
}

// src/services/devicesApi.ts
import { env } from '../config/env'

export const apiClient = new ApiClient(env.apiUrl)           // built at import, from a global
let queryClient: QueryClient | undefined                     // stashed by main.tsx so non-React code can reach it

export async function renameDevice(id: DeviceId, name: string): Promise<void> {
  await apiClient.post(`/devices/${id}`, { name })           // global reached from a leaf
  await queryClient?.invalidateQueries({ queryKey: ['devices'] })   // a second one, possibly unset
}

// devicesApi.test.ts — the test must rewrite shared state, and cannot run in isolation
vi.mock('../config/env', () => ({ env: { apiUrl: 'http://test' } }))   // leaks into every module that imported env
```

### After — dependency rejected upward, injected at the edge

```tsx
// src/services/devicesApi.ts
export class DevicesApi {
  constructor(private readonly client: ApiClient) {}         // injected, not global

  async rename(id: DeviceId, name: string): Promise<void> {
    await this.client.post(`/devices/${id}`, { name })
  }
}

// src/hooks/useRenameDevice.ts — the query client comes from the provider, not a module
export function useRenameDevice() {
  const api = useServices().devices
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ id, name }: RenameInput) => api.rename(id, name),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['devices'] }),
  })
}

// src/main.tsx — the environment is read ONLY in the composition root
const config = readAppConfig(import.meta.env, window.__RUNTIME_ENV__)
const queryClient = new QueryClient()
const services: Services = { devices: new DevicesApi(new ApiClient(config.apiUrl)) }

createRoot(rootElement).render(
  <QueryClientProvider client={queryClient}>
    <ServicesProvider value={services}>
      <App />
    </ServicesProvider>
  </QueryClientProvider>,
)
```

The test constructs a `DevicesApi` over an `ApiClient` whose requests MSW answers —
no module is mocked, no `vi.stubEnv`, tests run in isolation. The refactoring is
incremental: one clean island at a time, pushing the global up one level per
iteration, from 20 scattered accesses down to 2 in the composition root. Full worked
case — the dependency map, the island-by-island progression, and the test payoff:
`../examples/dependency-rejection.md`.

Silent at module level, in any module: constants, `as const` enums, types, pure
functions, the `createContext` key (the value lives in a provider), style imports.
Silent only in the composition root (`main.tsx` / `App.tsx`): `new QueryClient()`, the
router, the provider tree, `import.meta.env` and `window.__RUNTIME_ENV__` read once
into an `AppConfig`, a registry filled by hand. Reported anywhere else: a module-level
`let`, `new ApiClient()` at import, a `QueryClient` stashed in a module, a registry
filled at import time, `import.meta.env` in a hook or service, `localStorage` read at
module scope, a lazy singleton behind a getter.
