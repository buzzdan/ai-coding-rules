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
