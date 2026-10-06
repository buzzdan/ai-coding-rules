**Purpose**: Rung 0 — test leaf types in isolation, 100% coverage target

1. **Identify leaf types** - Pure functions and parsers (`parsePort`, `formatBytes`), hooks without I/O (through `renderHook`), leaf components with no fetch and no route
2. **Choose structure** - `it.each` with named rows (simple) or `renderWithProviders` (a component that reads the query client or the router)
3. **Import as a consumer would** - `import { parsePort } from './port'`; never a helper exported so a test can reach it
4. **Use in-memory implementations** - From `src/test-utils/` or local implementations
5. **Avoid pitfalls** - No `setTimeout` waits, no conditionals in test bodies, no assertions on state the user cannot see, no `vi.mock` of an internal hook or service

**Test structure:**
- Parametrized: Separate success/error `it.each` blocks (complexity = 1)
- `beforeEach`: Only for real infrastructure (`server.use`, fake timers, a store) — never to hide the literal a test should show
- A `name` on every `it.each` row (`it.each([{ name: 'plain', raw: '3x100ms', maxAttempts: 3 }])('parses $name', ...)`); object rows when a row carries more than two values

See reference.md for detailed patterns and examples.
