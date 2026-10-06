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
