1. **Find the lowest rung** that contains the behavior (see composition_ladder)
2. **Choose structure**: `describe`/`it` with `it.each` rows carrying a `name` (simple) or `renderWithProviders` setup (a page against MSW handlers)
3. **Import as a consumer would** (`import { useDevices } from './useDevices'`, the page from its folder) - test exported API only, never a helper exported so a test can reach it
4. **Compose real layers** - MSW handlers per API domain, the in-memory `PreferencesStore`, `vi.useFakeTimers()` for the clock, `renderWithProviders` (a fresh `QueryClient` with `retry: false` under `QueryClientProvider` + `MemoryRouter`)
5. **Avoid pitfalls**: No `setTimeout` waits (`findBy*`, `waitFor`), no conditionals in test bodies, no `vi.mock` of an internal hook or service

Ready after tests? Run linter: `npx tsc --noEmit && npx eslint . --fix && npx prettier --write .` (or the repository's `package.json` scripts)
