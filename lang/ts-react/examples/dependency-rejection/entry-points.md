```tsx
// src/hooks/useServices.ts — the context is a key; the value is built once, below
const ServicesContext = createContext<Services | undefined>(undefined)
export const ServicesProvider = ServicesContext.Provider
export function useServices(): Services {
  const services = useContext(ServicesContext)
  if (services === undefined) throw new Error('useServices() outside <ServicesProvider>')
  return services
}

// ✅ src/main.tsx — the environment is read ONLY here, at wiring time
const config = readAppConfig(import.meta.env, window.__RUNTIME_ENV__) // one AppConfig, validated once
const natsClient = new NATSClient(new WsSocket(), { url: config.natsUrl, token: config.natsToken })
const services: Services = {
  orders: new OrderService(natsClient, config.apiBaseUrl),
  users: new UserService(natsClient, config.apiBaseUrl),
}
createRoot(rootElement).render(<ServicesProvider value={services}><App /></ServicesProvider>)
```

Final state: 2 environment reads — `main.tsx`, and `renderWithProviders` in
`src/test-utils/`, which wraps the same provider around page tests with defaults read
from `.env.test` — down from 20 sideways accesses. `src/config/env.ts` is deleted;
`useProcessOrder()` asks `useServices().orders`; everything below is constructor-injected.
