Build each search over the language's source files (`{{.SrcGlob}}`); "test files"
means the files the repository's test runner picks up (`*{{.TestGlob}}`, a `tests/`
directory, or whatever the repository uses).

1. **Is a symbol public only so tests can reach it?**
   Detection: for each newly public function/type, search the non-test source files
   for references outside its defining file — count them.
   Violation: zero production call sites outside the package or module while test
   references exist — it was made public for tests; demote (rung 1) or promote
   (rung 2/3).

2. **Are {{.Unexported}} helpers tested directly?**
   Detection: find test files that can reach non-public symbols (an in-package test,
   an import of a private module, a test that reaches past the public surface), then
   search those files for calls to the package's non-public functions.
   Violation: any direct test of a private helper — that urge is the promotion
   signal; give the helper its own package instead.

3. **Does a new shared package have a role name?**
   Detection: list the shared-library directories and match their names against
   `util`, `utils`, `helpers`, `helper`, `common`, `shared`, `misc`.
   Violation: any hit — packages are named for a domain vocabulary, never a role.

4. **Is a new shared package a single noun rather than a vocabulary?**
   Detection: count the public types the new package declares and ask whether
   plausible domain siblings exist under the name.
   Violation: a package named after its one type (`kubeport`) with no room for
   siblings — fold into a vocabulary package (`networking`) or keep at rung 1/2.

5. **Did feature policy leak into a shared package?**
   Detection: search the shared package for feature-owned literals and constants
   (a product or feature name inside a string literal, say `"weka-`).
   Violation: any feature-specific literal or preference decision inside a
   domain-generic package — policy stays in the feature (Stage 2 of
   `R1-primitive-obsession.md`).

6. **Does a changed function envy another type's data?**
   Detection: for each changed function/method, count field/method accesses per
   value (occurrences of `<receiver>.` versus occurrences of `<parameter>.` in the
   body), for the receiver and for its most-touched parameter or field.
   Violation: accesses on one foreign value outnumber accesses on the receiver (or
   on all local data, for a free function) and the foreign type is yours to extend —
   Move Method to the Envied Type, then re-place via the ladder. A function that
   merely *reads* a foreign DTO once to adapt it at a boundary is not envy.
