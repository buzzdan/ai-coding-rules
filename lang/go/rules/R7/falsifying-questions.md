1. **Does any `t.Run` body contain a conditional?**
   Detection: `grep -rn -A6 't.Run(' --include='*_test.go' . | grep -nE 'if |switch '`
   and `grep -rn 'wantErr' --include='*_test.go' .`
   Violation: any conditional inside a case, or a `wantErr bool` field — success and
   error cases are fused; split the functions.

2. **Is any test in the internal package?**
   Detection: `grep -rn '^package ' --include='*_test.go' . | grep -v '_test$'`
   Violation: a test package without the `_test` suffix — it can reach privates;
   move to `pkg_test` and test the public API.

3. **Does a test construct a big object to exercise a leaf behavior?**
   Detection: read each new/changed test — compare the setup (fixtures, services,
   servers) against the assertion's subject; count setup lines vs. the one predicate
   actually checked.
   Violation: heavyweight construction whose assertions target logic a leaf type
   owns (or should own) — move the test down a rung, extracting the leaf if needed.

4. **Does a new behavior's test sit above the lowest rung that contains it?**
   Detection: for each new public method on a leaf type,
   `grep -rn '<Method>' --include='*_test.go' .` — is it exercised directly, or only
   through an orchestrator's test?
   Violation: leaf behavior reached only from above — add the rung-0 test; the
   orchestrator test keeps only the seam.

5. **Does a test assert on a fake's internals rather than observable behavior?**
   Detection: `grep -rn 'AssertExpectations\|AssertCalled\|\.calls\b' --include='*_test.go' .`;
   also flag assertions reading fields of a test double instead of querying the
   system under test.
   Violation: the test verifies the double — assert on real state via the public API
   (and the double itself is likely an R6 finding).

6. **Does any test sleep to synchronize?**
   Detection: `grep -rn 'time.Sleep' --include='*_test.go' .`
   Violation: any hit — replace with channels/wait groups.
