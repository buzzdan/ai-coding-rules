1. **Is a symbol public only so tests can reach it?**
   Detection: for each newly public function/class (no leading underscore, or newly
   listed in `__all__`),
   `grep -rn '<Symbol>' --include='*.py' . | grep -v 'test_\|_test.py\|conftest'` —
   count non-test references outside its defining module.
   Violation: zero production call sites outside the package while test files
   reference it — it was made public for tests; demote (rung 1) or promote
   (rung 2/3).

2. **Are `_private` helpers tested directly?**
   Detection: `grep -rnE 'import _[a-z]|from [a-z_.]+ import .*\b_[a-z_]+|\._[a-z_]+\(' --include='test_*.py' --include='*_test.py' .`
   — an import of a `_private` name, or a call through `obj._helper(...)` in a test
   body. `monkeypatch.setattr(mod, "_helper", ...)` is the same reach with a
   different verb.
   Violation: any direct test of a private helper — that urge is the promotion
   signal; give the helper its own module or package instead. The underscore is a
   convention, not a wall: the test runs, and that is why the question is asked.

3. **Does a new shared package have a role name?**
   Detection: `find . -name '*.py' -not -path '*/.venv/*' | grep -iE '/(util|utils|helpers|helper|common|shared|misc)(\.py|/__init__\.py)$'`
   Violation: any hit — `utils.py` and `common.py` are the Python spelling of the
   role-named package; modules are named for a domain vocabulary, never a role.

4. **Is a new shared package a single noun rather than a vocabulary?**
   Detection: `grep -cE '^class [A-Z]' <package>/*.py` and ask whether plausible
   domain siblings exist under the name.
   Violation: a package named after its one type (`kubeport/`) with no room for
   siblings — fold into a vocabulary package (`networking/`) or keep at rung 1/2.

5. **Did feature policy leak into a shared package?**
   Detection: grep the shared package for feature-owned literals and constants, e.g.
   `grep -rn '"weka-' <shared package>/`.
   Violation: any feature-specific literal or preference decision inside a
   domain-generic package — policy stays in the feature (Stage 2 of
   `R1-primitive-obsession.md`).

6. **Does a changed function envy another type's data?**
   Detection: for each changed function/method, count attribute accesses per value:
   `grep -oE '\bself\.[a-zA-Z_]+' <func body> | sort | uniq -c` versus the same
   count for its most-touched parameter (`grep -oE '\b<param>\.[a-zA-Z_]+'`).
   Violation: accesses on one foreign value outnumber accesses on `self` (or on all
   local data, for a free function) and the foreign type is yours to extend — Move
   Method to the Envied Type, then re-place via the ladder. A function that merely
   *reads* a foreign DTO once to adapt it at a boundary is not envy.
