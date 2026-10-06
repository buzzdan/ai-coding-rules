---
name: testing
description: |
  Use when creating leaf types, after refactoring, during implementation, or when testing advice is needed.
  Automatically invoked to write tests for new types, or use as testing expert advisor.
  Covers the composition ladder from rung-0 unit tests to whole-system tests, with emphasis on real in-memory dependencies.
  Ensures 100% coverage on leaf types with public API testing.
---

<objective>
Principles and patterns for writing effective TypeScript + React tests.
Writes tests autonomously based on code structure and type design, and serves as testing expert advisor.

**Reference**: See `reference.md` for comprehensive testutils patterns and DSL examples.
</objective>

<quick_start>
1. **Find the lowest rung** that contains the behavior (see composition_ladder)
2. **Choose structure**: `describe`/`it` with `it.each` rows carrying a `name` (simple) or `renderWithProviders` setup (a page against MSW handlers)
3. **Import as a consumer would** (`import { useDevices } from './useDevices'`, the page from its folder) - test exported API only, never a helper exported so a test can reach it
4. **Compose real layers** - MSW handlers per API domain, the in-memory `PreferencesStore`, `vi.useFakeTimers()` for the clock, `renderWithProviders` (a fresh `QueryClient` with `retry: false` under `QueryClientProvider` + `MemoryRouter`)
5. **Avoid pitfalls**: No `setTimeout` waits (`findBy*`, `waitFor`), no conditionals in test bodies, no `vi.mock` of an internal hook or service

Ready after tests? Run linter: `npx tsc --noEmit && npx eslint . --fix && npx prettier --write .` (or the repository's `package.json` scripts)
</quick_start>

<when_to_use>
<automatic_invocation>
- **Automatically invoked** by @linter-driven-development in Phase 2's RED step — one failing test per behavior, placed by the composition ladder
- **Automatically invoked** by @refactoring when new isolated types are created
- **Automatically invoked** by @code-designing after designing new types
- **After creating new leaf types** - Types that should have 100% unit test coverage
- **After extracting functions** during refactoring that create testable units
</automatic_invocation>

<manual_invocation>
- User explicitly requests tests to be written
- User asks for testing advice, recommendations, or "what to do"
- When testing strategy is unclear (table-driven vs suites)
- When choosing between dependency levels (in-memory vs binary vs test-containers)
- When adding tests to existing untested code
- When user needs testing expert guidance or consultation
</manual_invocation>
</when_to_use>

<philosophy>
**Test only the public API**
- Import the package as a consumer would, so privates are unreachable
- Test types through their constructors
- No testing private methods/functions — the urge to unit-test an unexported helper directly is a promotion signal: give the helper its own package (`../../rules/R4-helper-placement.md`), never test privates.

**No mocks — and a type that only satisfies a production interface in a test IS a mock**
- A "fake" is a *real implementation with fake data* (embedded DB, in-process HTTP server, fake binary, temp dir) — NOT a type written to satisfy a dependency interface, and NOT a patched-in stand-in.
- Terminology: the banned "mock" is an interface-injected or patched-in double. The "in-memory mock servers" elsewhere in this skill are fakes in this sense — real servers speaking the real protocol with configurable fake data — and remain the recommended stand-in for external APIs you don't control (wired via URL/config, never via a production interface).
- Use in-memory implementations (fastest, no external deps), in-process HTTP test servers, temp files/directories, or the real dependency.
- **Orchestrators are tested by wiring their real collaborators** (real Store/Evaluator over embedded DB + in-process external services), never by injecting doubles.
- If you are tempted to add an interface so a test can inject a fake, stop — that interface is a test-only smell. Depend on the concrete type instead (see @code-designing and `../../rules/R6-test-only-interfaces.md`).

**Coverage targets**
- Rung 0 (leaf types): 100% unit test coverage
- Higher rungs (orchestrating types): cover the delta each rung adds — its seams and emergent behaviors
- Critical workflows: top-rung (system) tests

**Assertions**: `expect` with the `@testing-library/jest-dom` matchers is the default — `toBeInTheDocument`, `toBeEnabled` and `toHaveAccessibleName` are the assertions of choice (`expect(screen.getByRole('button', { name: /save/i })).toBeEnabled()`, `expect(() => parsePort('')).toThrow(/empty/)`), scoped with `within(section).getByRole(...)` when the page holds more than one match; `toHaveBeenCalledTimes` only on a spy at the true boundary (a callback prop), never on an internal mock — but project convention wins — match the codebase you're in; never add a second assertion library.
</philosophy>

<composition_ladder>
Tests sit on a ladder of real composition, not a pyramid of layer percentages.

**Rung 0 — pure leaf types.** No I/O, no async tasks, no production dependencies.
Tests are plain constructions plus assertions: slice literals, value tables.
100% coverage is expected here — leaf types own most of the logic.

**Each rung above adds exactly one real production layer** — the real
implementation, never a mock. In-memory/in-process infrastructure counts as the
real layer: MSW handlers answering the real `fetch` (never a `vi.mock` of the service module),
an in-memory `PreferencesStore` with the production store's methods, `vi.useFakeTimers()` for the clock.

**Fake only the true external boundary** — the thing you genuinely cannot run
in-process (a third-party SaaS API, a hardware device). Everything inside the
boundary composes real.

**Placement rule: test each behavior at the lowest rung that contains it.** A
behavior expressible at rung 0 never gets tested through a rung-2 harness.

**Each rung tests its delta plus emergent behaviors**: the wiring/seams that rung
adds and behaviors that only exist through composition — not a re-test of
lower-rung logic (some overlap with leaf coverage is acceptable for orchestrators,
per `../../rules/R7-test-placement.md`).

The **top rung** is the whole system composed: black-box tests from `tests/` via
CLI/API, only the external boundary faked.

**Obligation table** — a template; adapt the rows per project and keep the adapted
table in the project docs:

| Kind of change | Owes a test at |
|---|---|
| New leaf type, or new behavior on one | Rung 0 |
| New seam between components X and Y | Rung 1 — the first rung containing the seam |
| New wiring through an infrastructure layer (queue, DB, RPC) | The rung that adds that layer |
| New externally observable behavior | Top rung |

The ladder is defined here; the placement review contract (falsifying questions)
lives in `../../rules/R7-test-placement.md`.
</composition_ladder>

<reusable_infrastructure>
Build shared test infrastructure in `src/test-utils/` (`setup.ts` starts MSW and
registers the jest-dom matchers; `mocks/server.ts` is the one `setupServer`;
`mocks/handlers/<domain>.ts` per API domain; `renderWithProviders.tsx`; `factories.ts`):
- MSW handlers per domain (`devicesHandlers` plus named overrides such as `devicesErrorHandler`, `emptyDevicesHandler`), in-memory stores, data factories (`makeDevice(overrides)`)
- Reusable across all test levels
- Test the infrastructure itself!
- Can serve the dev server as a mock backend (`msw/browser`) for manual testing

**Dependency Priority** (choose appropriate level):
1. **In-memory** (fastest): pure TypeScript, MSW handlers in the test process, an in-memory store, fake timers - use when testing your code's logic
2. **Binary** (isolated): the real API started as a child process (`child_process.spawn`), or its recorded exchange replayed by MSW - use when testing against a real service
3. **Test-containers** (realistic): programmatic Docker from the test (`testcontainers`) for the API and its database - use when you need real external services
4. **Docker-compose** (full stack): For complex multi-service scenarios, usually behind the Playwright run

Choose based on what you're testing, not dogmatically. In-memory is fastest but sometimes you need real services.

See reference.md for the Testing Library and MSW catalogue.
</reusable_infrastructure>

<workflow>

<unit_tests_workflow>
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
</unit_tests_workflow>

<integration_tests_workflow>
**Purpose**: Middle rungs — each adds one real layer; test the seams and emergent behaviors that layer brings

1. **Identify integration points** - Where a page, its hooks, the query layer and `apiClient` interact
2. **Choose dependencies** - Prefer: MSW handlers in-process > the real API as a child process > test-containers
3. **Write tests** - Imported as a consumer would, in `<Page>.test.tsx` beside the page (or `<Page>.integration.test.tsx` when the repository splits them by name, with a Vitest project or `include` pattern in `vitest.config.*` so the fast loop can skip them)
4. **Test workflows** - Cover happy path and error scenarios across boundaries (`server.use(devicesErrorHandler)`)
5. **Use real or test-support implementations** - Real providers, real routing, handlers whose fixture is a recorded exchange with the real API; no `vi.mock` of an internal hook or service

**File organization:**
```tsx
// src/pages/Devices/DevicesPage.test.tsx
import { screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { renderWithProviders } from '@/test-utils/renderWithProviders'
import { DevicesPage } from './DevicesPage'

// Page + hooks + query layer + apiClient against the devices handlers
```

See reference.md for integration test patterns with dependencies.
</integration_tests_workflow>

<system_tests_workflow>
**Purpose**: Top rung — black box test the entire system, critical end-to-end workflows

1. **Place in the repository's `e2e/` or `tests/` folder** - At project root, separate from `src/`; run by its Playwright (or Cypress) config, never by Vitest
2. **Test via the browser** - Playwright drives the built app at a URL; assertions are on what the user sees (`getByRole`, the URL, a download)
3. **Choose dependency level** based on what you're testing:
   - **In-memory**: Fastest, the dev server with `msw/browser` handlers or Playwright's `page.route` - use when testing your code's behavior
   - **Binary**: the real API started as a child process (`webServer` in `playwright.config.ts`) behind the built bundle
   - **Test-containers**: When you need real external services (the API and its database in Docker)
4. **Test critical workflows** - User journeys, not every edge case
5. **Run only when asked** - the skill runs the repository's e2e suite on request and never writes a new e2e test by default; a behavior goes to the lowest rung that contains it

**Example with a routed API:**
```ts
// e2e/devices.spec.ts - the built app against a routed API
import { expect, test } from '@playwright/test'

test('lists the devices of the selected cluster', async ({ page }) => {
  await page.route('**/api/clusters/c-1/devices', (route) =>
    route.fulfill({ json: { data: [{ id: 'd-1', name: 'edge-01', status: 'READY' }] } }),
  )

  await page.goto('/clusters/c-1/devices')

  await expect(page.getByRole('row', { name: /edge-01/ })).toBeVisible()
})
```

**Example with a real service process:**
```ts
// e2e/login.spec.ts - against the real API process started by playwright.config.ts
test('signs in and lands on the dashboard', async ({ page }) => {
  // `webServer` in playwright.config.ts starts the API and the built app, polls
  // their `url` until they answer (never a fixed sleep), and stops them after the run
  await page.goto('/')
  await page.getByLabel(/email/i).fill('ops@example.com')
  await page.getByRole('button', { name: /sign in/i }).click()

  await expect(page).toHaveURL(/\/dashboard$/)
})
```

See reference.md for the handlers behind the dev server and for test-containers.
</system_tests_workflow>

</workflow>

<key_patterns>
**Parametrized Tests (Cyclomatic Complexity = 1):**
- **NEVER add an `expectError` column** - It splits test logic and puts `if (expectError)` in the body
- **Max complexity = 1 inside a test body** - No if/else, no switch, no ternary, no `?.` guarding an assertion
- Separate success and error `it`s (`it.each(valid)('parses $name', ...)`, `it.each(invalid)('rejects $name', ...)`)
- A `name` on every `it.each` row; object rows (`{ name, raw, want }`) when a case carries more than two values
- Canonical violation, detection commands, and split pattern: `../../rules/R7-test-placement.md`; worked example in reference.md

**Rendering and queries:**
- `renderWithProviders` for anything that reads the query client or the router; plain `render` for a leaf component
- `screen.getByRole`/`getByLabelText` first, `getByText` next, `getByTestId` last; `queryBy*` only to assert absence
- `const user = userEvent.setup()` then `await user.click(...)`, never `fireEvent`
- `server.use(handler)` for a per-test override (reset by `afterEach` in `setup.ts`); hooks through `renderHook` with the providers `wrapper`
- `act` only around what RTL does not already wrap (advancing fake timers, a manual store update)

**Synchronization:**
- Never wait on `setTimeout` (flaky, slow)
- `await screen.findBy*(...)` or `await waitFor(() => expect(...))` for anything async; `vi.useFakeTimers()` + `await vi.advanceTimersByTimeAsync(ms)` for debounce and polling
- Every promise the test started is awaited before asserting; `vi.useRealTimers()` in `afterEach`

See reference.md for complete patterns with code examples.
</key_patterns>

<output_format>
After writing tests:

```
TESTING COMPLETE

Unit Tests:
- src/domain/port.test.ts: 100% (4 test cases)
- src/pages/Devices/useDevices.test.tsx: 100% (4 test cases)
- src/pages/Devices/DeviceRow.test.tsx: 100% (6 test cases)

Integration Tests:
- src/pages/Devices/DevicesPage.test.tsx: 3 workflows tested
- Dependencies: devices MSW handlers, in-memory PreferencesStore, fake timers

System Tests:
- e2e/devices.spec.ts: 2 end-to-end workflows (routed API)
- e2e/login.spec.ts: 1 full sign-in workflow (real API process)
- e2e/export.spec.ts: 1 export workflow (test-containers)

Test Infrastructure:
- src/test-utils/mocks/handlers/devices.ts: devices handlers and named overrides
- src/test-utils/stores/memoryPreferencesStore.ts: in-memory PreferencesStore
- src/test-utils/renderWithProviders.tsx: QueryClientProvider + MemoryRouter wrapper

Test Execution:
$ npx vitest run                      # all tests (in-memory only)
$ npx vitest run --coverage           # with coverage
$ npx playwright test                 # system tests (where the repository has them)

All tests pass
100% coverage on leaf types

Next Steps:
1. Run linter: npx tsc --noEmit && npx eslint . --fix && npx prettier --write .
2. If linter fails → use @refactoring skill
3. If linter passes → use @pre-commit-review skill
```
</output_format>

<testing_checklist>
<unit_tests_checklist>
- [ ] All unit tests import the module as a consumer would (`import { parsePort } from './port'`)
- [ ] Testing exported API only (no helper exported so a test can reach it)
- [ ] `it.each` rows carry a `name` and named fields, never bare positional arrays
- [ ] No conditionals in test bodies (complexity = 1)
- [ ] Using in-memory implementations from `src/test-utils/`
- [ ] No `setTimeout` waits (`findBy*`, `waitFor`, fake timers advanced explicitly)
- [ ] Leaf types have 100% coverage
</unit_tests_checklist>

<integration_tests_checklist>
- [ ] Test seams between a page, its hooks and `apiClient`
- [ ] Use MSW handlers or the API as a child process (avoid Docker)
- [ ] A Vitest project or `include` pattern for optional execution when the repository splits them by name (`*.integration.test.tsx` in `vitest.config.*`)
- [ ] Cover happy path and error scenarios across boundaries (`server.use(<domain>ErrorHandler)`)
- [ ] Real or test-support implementations (no `vi.mock` of an internal hook or service)
</integration_tests_checklist>

<system_tests_checklist>
- [ ] Located in `e2e/` or `tests/` at project root, under the repository's Playwright (or Cypress) config
- [ ] Black box testing through the browser (`page.getByRole`, the URL), never through component internals
- [ ] Appropriate dependency level chosen (routed API, real API process, or test-containers)
- [ ] Tests critical end-to-end workflows
- [ ] Dependencies documented (what's needed to run tests)
- [ ] CI-compatible (either fast in-memory or containerized setup)
</system_tests_checklist>

<test_infrastructure_checklist>
- [ ] Reusable handlers, stores and factories live in `src/test-utils/`; `setup.ts` only starts MSW and registers the matchers
- [ ] Test infrastructure has its own tests
- [ ] Named handlers make test setup readable (`server.use(emptyDevicesHandler)`)
- [ ] Can serve the dev server as a mock backend for manual testing
</test_infrastructure_checklist>

See reference.md for the Testing Library and MSW catalogue.
</testing_checklist>

<success_criteria>
Testing is complete when ALL of the following are true:

- [ ] All unit tests import the module as a consumer would and test the exported API only
- [ ] `it.each` rows carry a `name` and named fields
- [ ] No `expectError` column - success and error cases in separate `it`s
- [ ] Cyclomatic complexity = 1 inside every test body (no if/else, no switch, no ternary)
- [ ] Leaf types have 100% coverage
- [ ] Integration tests cover the page → hook → `apiClient` seams against MSW handlers
- [ ] System tests in `e2e/` or `tests/` with appropriate dependency level, run only when asked
- [ ] No `setTimeout` waits (`findBy*`, `waitFor`, fake timers advanced explicitly)
- [ ] No `vi.mock` of an internal hook or service
- [ ] Tests pass and linter approves
</success_criteria>
