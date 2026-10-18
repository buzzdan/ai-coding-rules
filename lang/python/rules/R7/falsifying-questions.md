1. **Does any test case body contain a conditional?**
   Detect-grep: `\b(expect_err|expect_error|should_fail)\b|raises: (bool|type)|pytest\.raises\(\w+\) if |^\s+(if|match) ` files=test
   Detection: a conditional inside a test function or a parametrized body, or a
   success-or-error column in the parameter table.
   Violation: any conditional inside a test function or a parametrized body, or a
   success-or-error column in the parameter table (an `expect_err` boolean, an
   expected exception type beside an expected value) — success and error cases are
   fused; split the functions.

2. **Does any test reach past the public surface?**
   Detect-grep: `^(from|import) .*\b_[a-z_]+|import _[a-z]|\._[a-z_]+\(` files=test
   Detection: imports of `_private` names, and calls through a private attribute.
   Violation: a test that imports or calls a `_private` name — the underscore is
   the package boundary in Python, and the test crossed it; import the package as
   a consumer would (`from app import user`) and test the public API.

3. **Does a test construct a big object to exercise a leaf behavior?**
   Detect: judgment
   Detection: read each new/changed test — compare the setup (fixtures requested
   in the signature, `conftest.py` fixtures, services, servers) against the
   assertion's subject; count setup lines vs. the one predicate actually checked.
   A fixture that builds the literal the test should show (`@pytest.fixture def
   port(): return Port("api", 8080)`) hides the input; a fixture for a temp
   directory or a fake server is real infrastructure.
   Violation: heavyweight construction whose assertions target logic a leaf type
   owns (or should own) — move the test down a rung, extracting the leaf if needed.

4. **Does a new behavior's test sit above the lowest rung that contains it?**
   Detect: judgment
   Detection: for each new public method on a leaf type,
   `grep -rn '<method>' --include='test_*.py' --include='*_test.py' .` — is it
   exercised directly, or only through an orchestrator's test?
   Violation: leaf behavior reached only from above — add the rung-0 test; the
   orchestrator test keeps only the seam.

5. **Does a test assert on a fake's internals rather than observable behavior?**
   Detect-grep: `assert_called|assert_any_call|assert_has_calls|\.call_count|\.call_args|\.mock_calls|\.calls\b` files=test
   Detection: also flag assertions reading attributes of a fake instead of querying the
   system under test.
   Violation: the test verifies the double — assert on real state via the public API
   (and the double itself is likely an R6 finding: a `MagicMock` standing in for a
   collaborator that should have had a real in-memory implementation).

6. **Does any test sleep to synchronize?**
   Detect-grep: `time\.sleep\(|await asyncio\.sleep\([0-9.]*[1-9]` files=test
   Violation: any hit — replace with `Event.wait(timeout)`, `Queue.get(timeout)`,
   `Thread.join(timeout)` or an awaited future; an `await asyncio.sleep(0)` that
   yields the loop once is scheduling, not synchronization, and stays.

7. **Does a mutant survive a leaf type's tests?**
   Detect-grep: `(<=?|>=?) *('.'|-?[0-9]+|[a-zA-Z_.]*len\b)|\blen\([^)]*\) *(<=?|>=?|==|!=)` exclude-path=(^|/)handlers/,(^|/)__main__\.py$,(^|/)main\.py$,(^|/)cli\.py$
   Detection: for each new or changed leaf package, with `paths_to_mutate` under
   `[tool.mutmut]` naming that package only, `mutmut run` then `mutmut results`;
   skip orchestrators, the top rung and any module that does I/O. `mutmut` not
   installed: propose the install the mechanics bullet describes before hunting; no
   survivors from a run that did not execute is not a pass. In a read-only review,
   where no tests may run, take the hand check instead: list the leaf's comparisons
   and boolean conditions, check the parametrize table for a row at each boundary
   value and on each side of each condition, and name the row that is missing. Open
   the leaf's test file for this, also when the file is outside the review's scope.
   Then read each error assertion of each leaf in scope, once per leaf file and not
   only where a hit row points. An assertion that matches only a word all the
   leaf's errors share (`match="tenant"`) cannot tell one error path from another, so
   a removed check or a changed message survives.
   On a whole-repository review this question is not judged: a mutation run or a
   hand check over every leaf does not fit a hunter's budget. The receipt reads
   `R7 Q7: <hits> hit(s) → per-leaf, not judged`, R7's tally takes the partial form,
   and the `not reached:` line names the three leaf directories with the most hits,
   each as the review that judges it: `R7 Q7: /{{.CmdPrefix}}-review <dir>`. On a
   scoped review the question is judged in full.
   Violation: any surviving mutant on a leaf module that is not recorded as
   equivalent — a missing parametrize row, an assertion on part of the message, or
   dead logic; name the mutant (`mutmut
   show <id>`) and the row that would kill it.
