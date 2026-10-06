# R8 — No Globals / Dependency Rejection

## Principle

Dependencies are passed down from the caller, never reached sideways: no
package-level mutable state, no import-time initialization writing state, no
singletons fetched from inside business logic, no library code that manufactures its
own root cancellation — cancellation flows from caller to callee. Globals are
acceptable only at entry points (`main`, handler setup, application wiring), where
they are read once and injected downward.

## Why

A global is a hidden parameter of every function that touches it. Hidden parameters
make code untestable except by mutating shared state — which forbids parallel tests,
lets state leak between tests, and hides from the reader what a function actually
needs. `env.Configs.X` reached from deep inside a publisher couples every caller to
one config object and makes swapping the value per-test or per-environment
impossible without global writes. A root cancellation context manufactured deep in a
call chain is the same sin in another form: it severs cancellation, timeouts, and
tracing from the request that is actually running. Passing dependencies down turns
each type into an island of clean code: constructor-injected (`R2-self-validating-types.md`), fully
testable with fake data, parallel-safe. Not every global is a defect: loggers
designed to be global, constants, and error sentinels are fine — the target is
mutable state and configuration reached sideways.

## Canonical example

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

## Design guidance

- **Reject the dependency upward.** A function that needs a value takes it — as a
  constructor argument on its type, or a parameter. The caller then faces the same
  choice, and the requirement bubbles up until it reaches an entry point that
  legitimately owns configuration.
- **Work bottom-up, one island at a time.** Start at the deepest usage (furthest
  from `main`), extract a clean constructor-injected type, and stop the iteration
  there — each step is a working, deployable state. Don't attempt a big-bang purge.
- **Pragmatic endpoint.** Globals at `main()`, handler setup, and top-level
  factories are acceptable; globals in business logic, data access, and library
  code are not. The goal is not zero globals — it is globals only where wiring
  happens.
- **Cancellation flows down.** Every function doing I/O takes the caller's
  cancellation context. A root context belongs in entry points and tests — never in
  library code; a library that manufactures its own root context has silently opted
  out of cancellation.
- **Import-time initialization computes nothing observable.** Initialization code
  that writes package state when the module loads is a hidden constructor with no
  error path and no injection point — replace it with an explicit constructor called
  from the edge.
- **Singletons are wiring, not access.** A lazily initialized package instance
  reached from business logic is a global with extra steps; construct once at the
  edge and pass it down.
- Constructor injection and validation of the injected deps:
  `R2-self-validating-types.md`. Forward design of the extracted types:
  @code-designing.

## Fix pattern

- **Extract Clean Island**: at the deepest global usage, create a type whose
  constructor takes the value (`NewNATSClient(addr)`); move the logic onto it.
- **Push the Global Up One Level**: each caller now constructs or receives the
  island; repeat per level until the global is read only at entry points. Full
  progression: `../examples/dependency-rejection.md`.
- **Replace Import-Time Initialization with a Constructor**: delete the load-time
  initializer, expose `NewX(...)` returning the value or an error, call it from the
  wiring code.
- **Pass Cancellation Down**: add the cancellation context as a parameter down the
  chain; delete every manufactured root context from library code.
- Multi-rule sequencing with extraction/storifying:
  `../skills/refactoring/reference.md`.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

Build each search over `*.ts` and `*.tsx` files outside `node_modules`, excluding
test files; "composition root" means `main.tsx`, `App.tsx`, a `providers.tsx` or
`bootstrap.ts` module, and the one config module (`src/config/env.ts`) — whichever
the repository uses to wire the application.

1. **Does any module declare mutable state at module level?**
   Detection: `grep -rnE '^(export )?(let|var) |^(export )?const [a-zA-Z_]+(: [^=]+)? *= *(new [A-Z]|\[\]|\{\}$)' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules . | grep -v '\.test\.'` —
   then sort the hits into three lists:
   - silent everywhere: an `UPPER_CASE` constant bound to a literal, an `as const`
     object or an `enum`, a do-nothing instance used as a constant (`NULL_SINK`), a
     `type`/`interface`/`class` declaration, a pure function, the `createContext(…)`
     key, a `styles` import;
   - silent only in the composition root: `const queryClient = new QueryClient()`,
     `createBrowserRouter(…)`, `const config = readAppConfig(…)`, the provider
     tree, a registry filled by hand;
   - reported everywhere else: a module-level `let`, a `Map`/`Set`/array/object a
     function writes into (`const REGISTRY = new Map<string, Handler>()` next to a
     `register()` that mutates it), `export const apiClient = new ApiClient()`, a
     module-level instance whose fields change (`import/no-mutable-exports` marks
     the exported `let`), a `let instance` behind a getter.
   Violation: a module-level binding that is written after import or holds
   configuration/state — reject it into a constructor argument or a provider value.

2. **Does any import-time code write state?**
   Detection: `grep -rnE '^(if |for |try|window\.|document\.|localStorage\.|sessionStorage\.|axios\.defaults|[a-zA-Z_.]+\.(register|set|add|push|use|configure|setDefault[A-Za-z]*)\()' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules . | grep -v '\.test\.'` —
   a statement at column 0 that is not a declaration, an import/export or the
   binding of a literal runs when the module is evaluated; read each for writes to
   module state or registrations with side effects (`register(…)` calls under the
   declarations, a `localStorage.getItem` at module scope, `axios.defaults.baseURL =
   …`, `window.addEventListener` outside an effect). A side-effect import
   (`import './registerWidgets'`) is the same code with the call hidden.
   Violation: import-time code mutating module state — replace with an explicit
   constructor or factory called from the composition root (Replace Import-Time
   Initialization with a Constructor).

3. **Does library code manufacture its own cancellation root?**
   Detection: `grep -rnE 'new QueryClient\(|window\.location\b|document\.(title|cookie|getElementById)|import \{[^}]*\bqueryClient\b' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules . | grep -v '\.test\.' | grep -vE 'main\.tsx|App\.tsx|providers?\.tsx'`
   and `grep -rnE 'new AbortController\(' --include='*.ts' --exclude-dir=node_modules src/services src/utils`.
   Violation: any hit outside the composition root. A hook takes its client from
   `useQueryClient()` and invalidates through it, never through a client a module
   imported; a service takes the `signal` from its caller (`queryFn({ signal })`, the
   effect that owns the fetch) and never conjures a controller of its own — that
   severs the caller's cancellation; the URL comes from `useSearchParams`/`useLocation`,
   never from `window.location` inside a hook or a service.

4. **Is a singleton reached sideways?**
   Detection: `grep -rnE '^let _?[a-zA-Z]+(: [A-Za-z<>|, ]+)?( *= *(undefined|null))?$|\?\?= new [A-Z]|if \(!_?[a-zA-Z]+\) _?[a-zA-Z]+ = new |export function get[A-Z][A-Za-z]*\(\)' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .` —
   a module-level `let instance` with a `getClient()` that fills it
   (`instance ??= new ApiClient()`), a memoized zero-argument getter that builds a
   service; check whether hooks or services call the getter.
   Violation: `getX()`-style access from inside logic — construct in the composition
   root, pass down through a provider or a constructor argument. (A memoized pure
   function of its arguments — `useMemo`, a cached formatter — is not this.)

5. **Does deep code read a global config?**
   Detection: `grep -rnE 'import\.meta\.env|process\.env|window\.__RUNTIME_ENV__|from .*config/env' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules . | grep -v '\.test\.' | grep -vE 'main\.tsx|App\.tsx|config/env\.ts|vite\.config|vite-env\.d\.ts'`
   Violation: config reads outside the composition root — each is a dependency to
   reject upward (`../examples/dependency-rejection.md`). The one module that builds
   the `AppConfig` from `import.meta.env` and `window.__RUNTIME_ENV__` belongs to the
   composition root; the value it builds travels down through a provider
   (`useAppConfig()`) or a constructor argument. Where ESLint's `no-restricted-syntax`
   bans `import.meta.env` outside the config module, it is this check made
   mechanical.

6. **Do tests mutate globals to run?**
   Detection: `grep -rnE "vi\.stubEnv\(|vi\.stubGlobal\(|vi\.mock\(['\"][^'\"]*(config|env)['\"]|window\.__RUNTIME_ENV__ *=|import\.meta\.env\.[A-Z_]+ *=|Object\.defineProperty\(window" --include='*.test.ts' --include='*.test.tsx' --include='setup.ts' --exclude-dir=node_modules .`
   Violation: a test writing shared state to inject a value — a `vi.stubEnv`, a
   `vi.mock('../config/env')`, an assignment to `window.__RUNTIME_ENV__` to reach the
   code under test — is evidence against the production code, which has a hidden
   dependency; fix the production code (a prop, a provider value, a constructor
   argument), not the test. (Stubbing a browser API the test runtime lacks —
   `matchMedia`, `ResizeObserver` — in `setup.ts` is the true external boundary, not
   this.)
