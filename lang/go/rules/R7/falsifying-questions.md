1. **Does any `t.Run` body contain a conditional?**
   Detect-grep: `\bwantErr\b|^\s*(} else )?if (tt|tc|c|tst|test)\.|^\s*switch (tt|tc|c|test)\.` files=test
   Detection: a `wantErr` field, or a conditional on the table case inside a `t.Run`
   body.
   Violation: any conditional inside a case, or a `wantErr bool` field — success and
   error cases are fused; split the functions.

2. **Is any test in the internal package?**
   Detect-grep: `^package [a-z][a-z0-9]*$` files=test
   Detection: a test file's `package` line without the `_test` suffix.
   Violation: a test package without the `_test` suffix — it can reach privates;
   move to `pkg_test` and test the public API.

3. **Does a test construct a big object to exercise a leaf behavior?**
   Detect: judgment
   Detection: read each new/changed test — compare the setup (fixtures, services,
   servers) against the assertion's subject; count setup lines vs. the one predicate
   actually checked.
   Violation: heavyweight construction whose assertions target logic a leaf type
   owns (or should own) — move the test down a rung, extracting the leaf if needed.

4. **Does a new behavior's test sit above the lowest rung that contains it?**
   Detect: judgment
   Detection: for each new public method on a leaf type,
   `grep -rn '<Method>' --include='*_test.go' .` — is it exercised directly, or only
   through an orchestrator's test?
   Violation: leaf behavior reached only from above — add the rung-0 test; the
   orchestrator test keeps only the seam.

5. **Does a test assert on a fake's internals rather than observable behavior?**
   Detect-grep: `AssertExpectations|AssertCalled|\.calls\b` files=test
   Detection: also flag assertions reading fields of a test double instead of querying the
   system under test.
   Violation: the test verifies the double — assert on real state via the public API
   (and the double itself is likely an R6 finding).

6. **Does any test sleep to synchronize?**
   Detect-grep: `time\.Sleep` files=test
   Violation: any hit — replace with channels/wait groups.

7. **Does a mutant survive a leaf type's tests?**
   Detect-grep: `(<=?|>=?) *('.'|-?[0-9]+|[a-zA-Z_.]*[Ll]en\b)|\b[Ll]en\([^)]*\) *(<=?|>=?|==|!=)`
   Detection: for each new or changed leaf package,
   `gremlins unleash ./path/to/leaf | grep -E '^\s*LIVED'`; skip orchestrators, the
   top rung and any package that does I/O. `gremlins` not on `PATH`: propose the
   install the mechanics bullet describes before hunting; an empty `LIVED` list from
   a run that did not execute, or whose mutants all timed out, is not a pass. In a
   read-only review, where no tests may run, take the hand check instead: list the
   leaf's comparisons and boolean conditions, check the table for a row at each
   boundary value and on each side of each condition, and name the row that is
   missing.
   Violation: any `LIVED` line on a leaf package that is not recorded as an
   equivalent mutant — a missing table row or dead logic; name the mutant (file,
   line, mutation) and the row that would kill it.
