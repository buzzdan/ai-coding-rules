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
     `createBrowserRouter(…)`, `const config = parseAppConfig(…)`, the provider
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
