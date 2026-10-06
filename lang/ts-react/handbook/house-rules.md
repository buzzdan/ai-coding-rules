Rules marked *(opinionated)* are stances, not TypeScript or React community norms;
the departure is deliberate.

### T1 — The type system is the contract (opinionated)

`strict` is on and the type checker passes. No `any` on a public signature
(`@typescript-eslint/no-explicit-any`, the `no-unsafe-*` family), no `as` outside the
boundary parser, no `!` (`@typescript-eslint/no-non-null-assertion`). An `object`- or
`unknown`-valued container crossing a boundary (`Record<string, unknown>`,
`Map<string, object>`) is the same suppression one level down: name the mapping (R1,
Name the Container). The types are what let `T | undefined` be a declared absence
instead of a hope.

**Review:** Does any public signature carry an `any`, an `as` or `!` outside the boundary parser, or an `object`- or `unknown`-valued container?

### T2 — Props and returned data are readonly

A component takes `Readonly<Props>` (`sonarjs/prefer-read-only-props`), a hook or a
service returns `readonly T[]`, `ReadonlyMap` or `ReadonlySet`, and a lookup table is
`as const`. A mutable prop or return type is an invitation to the in-place `.sort()`
and `.push()` that R12 hunts.

**Review:** Is any props type, returned array or table mutable?

### T3 — A component is a named function declaration, one per file (opinionated)

`function DevicesPage(props: Readonly<Props>)`, named-exported
(`react/function-component-definition`, `react/no-multi-comp`). A hook is `useX`,
beside its only caller until a second page needs it (R4). No component is defined
inside another (`react/no-unstable-nested-components`): the inner one is re-created
every render and loses its state. Three or more boolean props on one component are a
status union or two components (R11, Split Flag Argument).

**Review:** Is any component an arrow, a second component in a file, or defined inside another component's body?

### T4 — MSW is the boundary (opinionated)

HTTP is answered by MSW handlers, one file per API domain, started once in setup;
`vi.mock` of a module you own is R6's seam. The router, the auth SDK and the clock
(`vi.useFakeTimers`) are the boundaries a test may stub. Queries go by what the user
sees: `getByRole` and `getByLabelText` first, `getByText` next, `getByTestId` last.

**Review:** Does any test `vi.mock` a module the repository owns, or reach for a test id where a role or a label would do?

### T5 — An effect returns its cleanup, and a fetch belongs to the query layer (opinionated)

Every `setInterval`, subscription and `addEventListener` started in an effect has a
cleanup that stops it, and a fetch started there owns an `AbortController`. A `fetch`
in `useEffect` is a finding where the repository has TanStack Query: the query owns
the lifecycle, the cache and the abort. `react-hooks/exhaustive-deps` is never
disabled; a dependency the lint wants is a design question (R10), not a lint problem.

**Review:** Does any effect start a timer, subscription or fetch without a cleanup, fetch where a query hook would do, or disable `react-hooks/exhaustive-deps`?
