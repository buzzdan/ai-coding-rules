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
