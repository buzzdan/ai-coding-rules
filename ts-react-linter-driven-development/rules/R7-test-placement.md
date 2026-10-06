# R7 — Test Placement

## Principle

Every behavior is tested at the lowest rung of the composition ladder that contains
it: rung 0 is pure leaf types (unit tests with literal inputs, 100% coverage, public
API only, imported as a consumer would); each rung above adds exactly one real production
layer; only the true external boundary is ever faked. Orchestrating types get
integration-style tests that cover the seams between their real collaborators — some
overlap with leaf coverage is fine; leaf behavior tested *only* from above is not. On
a leaf type, coverage is the floor and the mutation score is the claim: a leaf's
tests must fail when its logic is changed, and a mutant that survives them is a
missing row or dead logic.

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
asserting on a fake's internals verifies the double, not the system. Line coverage
cannot tell either of those apart from a real test: a table that runs every line and
asserts nothing scores 100%. Mutation testing checks the claim coverage only
implies — flip a comparison, negate a branch, drop a statement, and rerun the suite;
a mutant the suite lets live marks logic no test pins down. It is worth its
runtime exactly where the logic is: rung 0, where the tests are literal tables and
the suite is fast. Orchestrators are not mutated; their seams are covered by wiring,
and a mutation run over them pays the harness cost per mutant for findings that
belong to a leaf anyway. The full
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
- **Mutation score on leaf types only**: once a leaf's tests cover it, run the
  mutation tool over that leaf's package — never over orchestrators, the top rung or
  the whole module — and triage every survivor: a *missing row* (add the literal that
  tells the mutant from the original), *dead logic* (the mutant is unreachable —
  delete the code, not the mutant), or an *equivalent mutant* (the change is
  behavior-preserving — note it in the test file, once, with the reason). No survivor
  is left untriaged; scope the run to the leaf packages the change touched so it
  stays as fast as the tables it checks.
- **Mutation mechanics**: `npx stryker run` (StrykerJS) with a `stryker.config.mjs`
  whose `mutate` lists the leaf modules only — `src/**/parse*.ts`, reducers, a pure
  hook's helpers; `.ts`, never `.tsx` components, whose mutants are killed only
  through slow render tests, and never the whole `src/` tree — after the leaf's tests
  are green there and after each fix. `testRunner: 'vitest'` through
  `@stryker-mutator/vitest-runner` (the Jest runner where the repository tests with
  Jest) so the run reuses the repository's tests, never a second runner;
  `coverageAnalysis: 'perTest'` so only the tests covering a mutant run;
  `--incremental` between fixes; `@stryker-mutator/typescript-checker` enabled, so
  a mutant that breaks the types is reported `CompileError` and never counted as
  killed. Each mutant runs in a sandbox copy under `.stryker-tmp/`, never in the
  checkout (`inPlace` stays at its default, `false`). The `clear-text` reporter's
  `Survived` lines carry the file, the line and the replacement — that is the row to
  write. When Stryker is not installed, propose adding it with the repository's
  package manager (`yarn add -D`, `pnpm add -D`, `npm i -D` or `bun add -d`
  `@stryker-mutator/core @stryker-mutator/vitest-runner
  @stryker-mutator/typescript-checker`) and a `mutate` script beside `test` and
  `lint` in `package.json` that runs `stryker run`; check the runner's supported
  Vitest major against the repository's before proposing it. Ask first, never
  install silently, and never read a run that did not execute as a clean one.
  Stryker mutates equality, relational and logical operators, literals and optional
  chaining, so the hand check's boundary rows mostly confirm its report rather than
  cover a blind spot.
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
- **Kill the surviving mutant**: add the table row whose literal input distinguishes
  the mutant from the original; when no input can, the mutated code was dead — delete
  it; when the mutant is provably equivalent, record why beside the tests.
- **Replace doubles with real collaborators**: delete the mock, wire the real
  dependency over fake data (`R6-test-only-interfaces.md`; @testing for harnesses).
- **Replace sleep with synchronization**: an event, channel or wait primitive with a
  timeout, never a fixed pause.
- **Delete private-function tests**: cover through the parent's public API, or
  promote the helper (`R4-helper-placement.md`).

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Does any test case body contain a conditional?**
   Detect-grep: `\b(expectError|expectErr|shouldFail|shouldThrow|throws: (true|false))\b|^\s+(if|switch) ` files=test
   Detection: a conditional inside a test body or an `it.each` callback, or a
   success-or-error column in the row table; a ternary in an `expect(…)` argument
   is the same branch in one line and is read by hand.
   Violation: any conditional inside a test body or an `it.each` callback, or a
   success-or-error column in the row table (an `expectError` boolean, an expected
   error class beside an expected value) — success and error cases are fused; split
   the blocks.

2. **Does any test reach past the public surface?**
   Detect-grep: `__test__|__testing__|exported for test|export \{[^}]*\b_[a-z]|vi\.spyOn\([a-zA-Z]+, '[a-z]` files=all
   Detection: exports that exist only for a test, and a spy placed on a module's
   own export to intercept an internal call.
   Violation: a test that imports a helper exported for it, a `__test__` bag, or an
   `export` added to a module in the same diff as its test — the `export` keyword is
   the module boundary in TypeScript, and the test crossed it; import the page or
   the hook as a consumer would and test the public API.

3. **Does a test construct a big object to exercise a leaf behavior?**
   Detect: judgment
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
   Detect: judgment
   Detection: for each new exported function on a leaf module,
   `grep -rn '<function>' --include='*.test.ts' --include='*.test.tsx' --exclude-dir=node_modules .` —
   is it exercised directly, or only through a page's render test?
   Violation: leaf behavior reached only from above — add the rung-0 test; the page
   test keeps only the seam.

5. **Does a test assert on a fake's internals rather than observable behavior?**
   Detect-grep: `toHaveBeenCalled(Times|With|Once)?\(|toHaveBeen(Last|Nth)CalledWith|\.mock\.(calls|results|lastCall)` files=test
   Detection: also flag assertions reading a `vi.fn()`'s record instead of querying
   the screen or the hook's result.
   Violation: the test verifies the double — assert on what the user sees or the hook
   returns (and the double itself is likely an R6 finding: a `vi.mock` of an internal
   service standing in for the MSW handler that should have answered). A callback
   prop handed to the component under test (`onSelect`) is that component's
   observable output; asserting on it is not this finding.

6. **Does any test sleep to synchronize?**
   Detect-grep: `setTimeout\(|advanceTimersByTime\(|new Promise\(\(?resolve|runAllTimers\(` files=test
   Violation: a fixed wait for a real async (a fetch, a state update, a transition) —
   replace with `findBy*`, `waitFor` or an `await` of the promise the code returns;
   `vi.useFakeTimers` plus `advanceTimersByTime` driving a debounce or a poll
   interval that is itself under test is the clock as the boundary, not
   synchronization, and stays.

7. **Does a mutant survive a leaf type's tests?**
   Detect-grep: `(<=?|>=?) *('.'|-?[0-9]+|[a-zA-Z_.]*\.length\b)|\.length *(<=?|>=?|===|!==)`
   Detection: for each new or changed leaf module, `npx stryker run` with a
   `stryker.config.mjs` whose `mutate` lists that module only (`.ts` leaves —
   parsers, reducers, a pure hook's helpers — never `.tsx` components, whose mutants
   die only through slow render tests), `--incremental` between fixes; Stryker runs
   each mutant in a sandbox copy under `.stryker-tmp/`, never in the checkout. Read
   the `clear-text` reporter: a `Survived` line carries the file, the line and the
   replacement, and a `CompileError` line is a mutant the types rejected, not a
   kill. Skip orchestrators, the top rung and any module that does I/O. Stryker
   not installed (`@stryker-mutator/core` absent from `devDependencies`): propose
   the install the mechanics bullet describes before hunting; no survivors from a
   run that did not execute is not a pass. In a read-only review, where no tests
   may run, take the hand check instead: list the leaf's comparisons and boolean
   conditions, check the `it.each` table for a row at each boundary value and on
   each side of each condition, and name the row that is missing.
   Violation: any surviving mutant on a leaf module that is not recorded as
   equivalent — a missing `it.each` row or dead logic; name the mutant (file, line,
   replacement from the `Survived` line) and the row that would kill it.
