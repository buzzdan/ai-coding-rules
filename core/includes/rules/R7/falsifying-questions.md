Test files are the ones the repository's test runner picks up (`*{{.TestGlob}}`, a
`tests/` directory, or whatever the repository uses); build each search over them.

1. **Does any test case body contain a conditional?**
   Detection: search the test files for `if`/`switch`/`match` inside a test function
   or a parametrized case, and for a success-or-error flag in a case table
   (`expectError`, `shouldFail`, `raises` as a boolean column).
   Violation: any conditional inside a case, or a boolean expect-error field —
   success and error cases are fused; split the functions.

2. **Does any test reach past the public surface?**
   Detection: find test files that import or declare themselves inside the package
   under test rather than importing it as a consumer would (an in-package test, an
   import of a private module or an {{.Unexported}} name).
   Violation: a test that can reach privates — move it to the consumer's side and
   test the public API.

3. **Does a test construct a big object to exercise a leaf behavior?**
   Detection: read each new/changed test — compare the setup (fixtures, services,
   servers) against the assertion's subject; count setup lines vs. the one predicate
   actually checked.
   Violation: heavyweight construction whose assertions target logic a leaf type
   owns (or should own) — move the test down a rung, extracting the leaf if needed.

4. **Does a new behavior's test sit above the lowest rung that contains it?**
   Detection: for each new public method on a leaf type, search the test files for
   its name — is it exercised directly, or only through an orchestrator's test?
   Violation: leaf behavior reached only from above — add the rung-0 test; the
   orchestrator test keeps only the seam.

5. **Does a test assert on a fake's internals rather than observable behavior?**
   Detection: search the test files for the mocking library's verification calls
   (`assertExpectations`, `assertCalled`, `assert_called_with`, `.calls`); also flag
   assertions reading fields of a test double instead of querying the system under
   test.
   Violation: the test verifies the double — assert on real state via the public API
   (and the double itself is likely an R6 finding).

6. **Does any test sleep to synchronize?**
   Detection: search the test files for the language's sleep call (`time.Sleep`,
   `time.sleep`, `setTimeout`, `Thread.sleep`).
   Violation: any hit — replace with an event, channel or wait primitive with a
   timeout.

7. **Does a mutant survive a leaf type's tests?**
   Detection: for each new or changed leaf type, run the repository's mutation
   testing tool over that leaf's package only (the mechanics bullet names the tool
   and the command) and read its list of survivors; skip orchestrators, the top
   rung and any package that does I/O. A tool the language has but the machine
   lacks is proposed for install as the mechanics bullet says, never skipped and
   never counted as a pass. Without any tool, list the leaf's comparisons
   and boolean conditions, check the table for a row at each boundary value and on
   each side of each condition, and hand-flip any operator whose rows are missing
   (`<` to `<=`, `>` to `>=`, a condition negated), run the leaf's tests, revert.
   Violation: any survivor on a leaf type that is not recorded as equivalent — a
   missing table row or dead logic; name the mutant (file, line, operator) and the
   row that would kill it.
