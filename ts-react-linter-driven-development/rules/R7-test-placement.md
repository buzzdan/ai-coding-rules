# R7 — Test Placement

## Principle

Every behavior is tested at the lowest rung of the composition ladder that contains
it: rung 0 is pure leaf types (unit tests with literal inputs, 100% coverage, public
API only, imported as a consumer would); each rung above adds exactly one real production
layer; only the true external boundary is ever faked. Orchestrating types get
integration-style tests that cover the seams between their real collaborators — some
overlap with leaf coverage is fine; leaf behavior tested *only* from above is not.

## Why

A behavior tested above its lowest rung pays for machinery the behavior doesn't
need: big-object construction, harnesses, fakes — and when it fails, the failure
points at the orchestration, not at the leaf that owns the bug. Tested at its rung,
the same behavior is a table of literals that pinpoints its owner. The placement
rule is also the enforcement arm of the design rule: if a leaf behavior *cannot* be
tested with literals, the logic is trapped in an orchestrator and R1/R3 extraction
is owed (`R1-primitive-obsession.md` Stage 3 shows the payoff — a K8s fixture test
collapsing into a slice-literal test). Discipline inside the tests matters for the
same reason: a conditional inside a table case means one case is really two, and a test
asserting on a fake's internals verifies the double, not the system. The full
composition ladder and harness patterns live in @testing; this rule is the placement
and review contract.

## Canonical example

### Before — anti-patterns stacked

```tsx
import { validateEmailInternal } from './usersApi'          // exported only so a test can reach it
import { createUser } from '../../services/usersApi'

vi.mock('../../services/usersApi')                           // a double instead of the collaborator

it('validates an email', () => {                             // testing a private
  expect(validateEmailInternal('test@example.com')).toBe(true)
})

it('creates a user', async () => {
  const user = userEvent.setup()
  render(<CreateUserForm />)
  await user.type(screen.getByLabelText('Email'), 'test@example.com')
  await user.click(screen.getByRole('button', { name: 'Create' }))
  expect(vi.mocked(createUser)).toHaveBeenCalledTimes(1)     // asserts on the fake, not on behaviour
})

it.each([                                                    // success and error fused
  { raw: '3x100ms', expectError: false },
  { raw: '0x100ms', expectError: true },
])('parsePolicy($raw)', ({ raw, expectError }) => {
  if (expectError) {                                         // a conditional inside a case
    expect(() => parsePolicy(raw)).toThrow()
  } else {
    expect(parsePolicy(raw).maxAttempts).toBe(3)
  }
})

it('shows the devices', async () => {
  render(<DeviceList />)
  await new Promise((resolve) => setTimeout(resolve, 100))  // flaky
  expect(screen.getByText('edge-01')).toBeInTheDocument()
})
```

### After — right rung, real collaborators, observable behaviour

```tsx
import { renderWithProviders } from '@/test-utils/renderWithProviders'
import { CreateUserForm } from './CreateUserForm'           // the page's public module, as a consumer would
import { DeviceList } from './DeviceList'
import { parsePolicy, PolicyError } from '@/retry/policy'

it('creates a user and shows it', async () => {
  const user = userEvent.setup()                             // MSW handlers answer the POST and the GET: real HTTP, fake data
  renderWithProviders(<CreateUserForm />)

  await user.type(screen.getByLabelText('Email'), TEST_USER.email)
  await user.click(screen.getByRole('button', { name: 'Create' }))

  expect(await screen.findByText(TEST_USER.email)).toBeInTheDocument()   // verify via what the user sees
})

describe('parsePolicy', () => {
  it.each([
    { name: 'plain', raw: '3x100ms', maxAttempts: 3 },
    { name: 'single attempt', raw: '1x100ms', maxAttempts: 1 },
  ])('accepts $name', ({ raw, maxAttempts }) => {
    expect(parsePolicy(raw).maxAttempts).toBe(maxAttempts)
  })

  it.each([
    { name: 'zero attempts', raw: '0x100ms' },
    { name: 'missing delay', raw: '3x' },
  ])('rejects $name', ({ raw }) => {
    expect(() => parsePolicy(raw)).toThrow(PolicyError)
  })
})

it('shows the devices', async () => {
  renderWithProviders(<DeviceList />)
  expect(await screen.findByText('edge-01')).toBeInTheDocument()   // waits for the real async, bounded by a timeout
})
```

Email validation itself is a leaf behaviour — it belongs one rung down, as a unit
test on `parseEmail` with literal strings, not inside the form test and not behind an
`export` added so a test could reach `validateEmailInternal`. The two `it.each`
tables are the split the rule asks for: one block asserts values, one asserts the
throw, and neither case body branches.

## Design guidance

- **Leaf types (rung 0)**: 100% unit coverage; constructed only through their public
  constructors; inputs are literals; imported as a consumer would, so privates are
  unreachable.
  Most of the codebase's logic should live here (`R1-primitive-obsession.md`).
- **Orchestrating types**: integration-style tests wiring real collaborators — real
  store over an embedded DB, real client against an in-process HTTP server — never
  interface-injected doubles (`R6-test-only-interfaces.md`). They cover the seams;
  overlapping a leaf's happy path while doing so is acceptable.
- **Fake only the true external boundary** — the API you don't control — and fake it
  with a real server speaking the real protocol, wired via URL/config.
- **Complexity 1 inside every test case**: no if/else, no switch. A success-or-error
  flag in one table is the canonical violation — it folds success and error cases
  into one table and pays with a conditional. Split into a success function and an
  error function.
- **The urge to test a private is a placement signal**, never a license: it means
  the helper deserves its own package (`R4-helper-placement.md`), where its public
  API is legitimately testable.
- **Mechanics**: a `name` field on every `it.each` row and `$name` in the title so a
  failure names its case, and object rows rather than positional arrays when a row
  carries more than two values; no `setTimeout` waits — `findBy*`, `waitFor` or an
  awaited promise; `beforeEach` and `src/test-utils/` only for real infrastructure
  (the MSW server, `renderWithProviders`, a fake clock), never to hide the literal a
  test should show; import the page's public module or the hook as a consumer would,
  never a helper exported only for the test; queries by role and label first,
  `getByText` next, `getByTestId` last; success and error cases in separate
  `accepts …`/`rejects …` blocks, never one table with an `expectError` column and a
  branch on it; tests colocated (`X.test.tsx` by `X.tsx`), `tests/` for Playwright.
- Full ladder, harness patterns, and dependency levels (in-memory → binary →
  containers): @testing.

## Fix pattern

- **Move the behavior down a rung**: rewrite the big-object test as a leaf unit test
  with literal inputs; if the leaf doesn't exist yet, that is an R1/R3 extraction
  first (`../examples/storify-leaf-type.md` shows the pair).
- **Split Success and Error Tables**: one function asserting values, one asserting
  errors — complexity 1 in both.
- **Replace doubles with real collaborators**: delete the mock, wire the real
  dependency over fake data (`R6-test-only-interfaces.md`; @testing for harnesses).
- **Replace sleep with synchronization**: an event, channel or wait primitive with a
  timeout, never a fixed pause.
- **Delete private-function tests**: cover through the parent's public API, or
  promote the helper (`R4-helper-placement.md`).

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Does any test case body contain a conditional?**
   Detection: `grep -rn -A12 -E '(it|test)\.each\(' --include='*.test.ts' --include='*.test.tsx' --exclude-dir=node_modules . | grep -E '^\S+-[0-9]+-\s+(if |switch |\? )'`
   and `grep -rnE 'expectError|expectErr|shouldFail|shouldThrow|throws: (true|false)' --include='*.test.ts' --include='*.test.tsx' --exclude-dir=node_modules .`
   Violation: any conditional inside a test body or an `it.each` callback, or a
   success-or-error column in the row table (an `expectError` boolean, an expected
   error class beside an expected value) — success and error cases are fused; split
   the blocks.

2. **Does any test reach past the public surface?**
   Detection: `grep -rnE '__test__|__testing__|exported for test|export \{[^}]*\b_[a-z]' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`
   for exports that exist only for a test, and
   `grep -rnE "vi\.spyOn\([a-zA-Z]+, '[a-z]" --include='*.test.ts' --include='*.test.tsx' --exclude-dir=node_modules .`
   for a spy placed on a module's own export to intercept an internal call.
   Violation: a test that imports a helper exported for it, a `__test__` bag, or an
   `export` added to a module in the same diff as its test — the `export` keyword is
   the module boundary in TypeScript, and the test crossed it; import the page or
   the hook as a consumer would and test the public API.

3. **Does a test construct a big object to exercise a leaf behavior?**
   Detection: read each new/changed test — compare the setup (`renderWithProviders`,
   handlers registered with `server.use`, a `QueryClient`, provider wrappers, a
   router with a route tree) against the assertion's subject; count setup lines vs.
   the one predicate actually checked. A factory that builds the literal the test
   should show (`buildPort()` with defaults for every field) hides the input; an MSW
   handler or a `QueryClient` is real infrastructure.
   Violation: heavyweight construction whose assertions target logic a leaf owns (or
   should own) — rendering a page to check what `formatBytes` prints — move the test
   down a rung, extracting the leaf if needed.

4. **Does a new behavior's test sit above the lowest rung that contains it?**
   Detection: for each new exported function on a leaf module,
   `grep -rn '<function>' --include='*.test.ts' --include='*.test.tsx' --exclude-dir=node_modules .` —
   is it exercised directly, or only through a page's render test?
   Violation: leaf behavior reached only from above — add the rung-0 test; the page
   test keeps only the seam.

5. **Does a test assert on a fake's internals rather than observable behavior?**
   Detection: `grep -rnE 'toHaveBeenCalled(Times|With|Once)?\(|toHaveBeen(Last|Nth)CalledWith|\.mock\.(calls|results|lastCall)' --include='*.test.ts' --include='*.test.tsx' --exclude-dir=node_modules .`;
   also flag assertions reading a `vi.fn()`'s record instead of querying the screen
   or the hook's result.
   Violation: the test verifies the double — assert on what the user sees or the hook
   returns (and the double itself is likely an R6 finding: a `vi.mock` of an internal
   service standing in for the MSW handler that should have answered). A callback
   prop handed to the component under test (`onSelect`) is that component's
   observable output; asserting on it is not this finding.

6. **Does any test sleep to synchronize?**
   Detection: `grep -rnE 'new Promise\([^)]*setTimeout|setTimeout\([^,]+, *[1-9][0-9]*\)|advanceTimersByTime\(|runAllTimers\(' --include='*.test.ts' --include='*.test.tsx' --exclude-dir=node_modules .`
   Violation: a fixed wait for a real async (a fetch, a state update, a transition) —
   replace with `findBy*`, `waitFor` or an `await` of the promise the code returns;
   `vi.useFakeTimers` plus `advanceTimersByTime` driving a debounce or a poll
   interval that is itself under test is the clock as the boundary, not
   synchronization, and stays.
