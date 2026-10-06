```tsx
// ❌ a module-level config built at import, reached from a leaf
import { env } from '../config/env'

export const apiClient = new ApiClient(env.apiUrl) // built at import, from a global

export async function renameDevice(id: DeviceId, name: string): Promise<void> {
  await apiClient.post(`/devices/${id}`, { name })
}

// ✅ read once in the composition root, pushed down as a value
export class DevicesApi {
  constructor(private readonly client: ApiClient) {}

  async rename(id: DeviceId, name: string): Promise<void> {
    await this.client.post(`/devices/${id}`, { name })
  }
}

// main.tsx — the environment is read ONLY here
const config: AppConfig = readAppConfig(import.meta.env, window.__RUNTIME_ENV__)
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

> **In TypeScript:** silent everywhere: constants, `as const` enums, types, pure
> functions, the `createContext` key (the value lives in a provider), style imports.
> Silent only in the composition root (`main.tsx` / `App.tsx`): `new QueryClient()`,
> the router, the provider tree, `import.meta.env` and `window.__RUNTIME_ENV__` read
> once into an `AppConfig`. Reported elsewhere: a module-level `let`, `new ApiClient()`
> at import, a `QueryClient` stashed in a module so non-React code can reach it,
> `import.meta.env` inside a hook or service, `localStorage` read at module scope, a
> lazy singleton behind a getter. React context is the composition mechanism; a module
> singleton is the finding when a provider would do. A test that `vi.stubEnv`s or
> `vi.mock`s a config module is evidence against the production code, not a fix for
> the test.
