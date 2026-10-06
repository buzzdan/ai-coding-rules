1. **Is a symbol exported only so tests can reach it?**
   Detect: judgment
   Detection: for each newly exported func/type,
   `grep -rn '<Symbol>' --include='*.go' . | grep -v _test.go` — count non-test
   references outside its defining file.
   Violation: zero production call sites outside the package while `*_test.go`
   references exist — it was exported for tests; demote (rung 1) or promote
   (rung 2/3).

2. **Are unexported helpers tested directly?**
   Detect-grep: `^package [a-z][a-z0-9]*$` files=test
   Detection: a test file whose package line lacks the `_test` suffix is an internal
   test package; grep those files for calls to lowercase functions
   defined in the package.
   Violation: any direct test of a private helper — that urge is the promotion
   signal; give the helper its own package instead.

3. **Does a new shared package have a role name?**
   Detect-path: `(^|/)(internal/)?pkg/(util|utils|helpers|helper|common|shared|misc)/`
   Detection: any scope path inside a role-named shared package.
   Violation: any hit — packages are named for a domain vocabulary, never a role.

4. **Is a new shared package a single noun rather than a vocabulary?**
   Detect: judgment
   Detection: `grep -c '^type [A-Z]' internal/pkg/<name>/*.go` and ask whether
   plausible domain siblings exist under the name.
   Violation: a package named after its one type (`kubeport`) with no room for
   siblings — fold into a vocabulary package (`networking`) or keep at rung 1/2.

5. **Did feature policy leak into a shared package?**
   Detect: judgment
   Detection: grep the shared package for feature-owned literals and constants, e.g.
   `grep -rn '"weka-' internal/pkg/`.
   Violation: any feature-specific literal or preference decision inside a
   domain-generic package — policy stays in the feature (Stage 2 of
   `R1-primitive-obsession.md`).

6. **Does a changed function envy another type's data?**
   Detect: judgment
   Detection: for each changed function/method, count field/method accesses per
   value: `grep -o '<recv>\.[a-zA-Z]*' <func body> | sort | uniq -c` versus the same
   count for its most-touched parameter or field. A parameter that is a map or
   slice is accessed by `[`, comma-ok lookup, `len(` and `range` rather than by
   field; count those the same way.
   Violation: accesses on one foreign value outnumber accesses on the receiver (or
   on all local data, for a free function) and the foreign type is yours to extend —
   Move Method to the Envied Type, then re-place via the ladder. A function that
   merely *reads* a foreign DTO once to adapt it at a boundary is not envy.
