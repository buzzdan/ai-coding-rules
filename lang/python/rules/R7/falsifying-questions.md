1. **Does any test case body contain a conditional?**
   Detection: `grep -rn -A12 '@pytest.mark.parametrize' --include='test_*.py' --include='*_test.py' . | grep -E '^\S+-[0-9]+-\s+(if |match )'`
   and `grep -rnE 'expect_err|expect_error|should_fail|raises: (bool|type)|pytest\.raises\(\w+\) if ' --include='test_*.py' --include='*_test.py' .`
   Violation: any conditional inside a test function or a parametrized body, or a
   success-or-error column in the parameter table (an `expect_err` boolean, an
   expected exception type beside an expected value) — success and error cases are
   fused; split the functions.

2. **Does any test reach past the public surface?**
   Detection: `grep -rnE '^(from|import) .*\b_[a-z_]+|import _[a-z]' --include='test_*.py' --include='*_test.py' .`
   for imports of `_private` names, and
   `grep -rnE '\._[a-z_]+\(' --include='test_*.py' --include='*_test.py' .` for calls
   through a private attribute.
   Violation: a test that imports or calls a `_private` name — the underscore is
   the package boundary in Python, and the test crossed it; import the package as
   a consumer would (`from app import user`) and test the public API.

3. **Does a test construct a big object to exercise a leaf behavior?**
   Detection: read each new/changed test — compare the setup (fixtures requested
   in the signature, `conftest.py` fixtures, services, servers) against the
   assertion's subject; count setup lines vs. the one predicate actually checked.
   A fixture that builds the literal the test should show (`@pytest.fixture def
   port(): return Port("api", 8080)`) hides the input; a fixture for a temp
   directory or a fake server is real infrastructure.
   Violation: heavyweight construction whose assertions target logic a leaf type
   owns (or should own) — move the test down a rung, extracting the leaf if needed.

4. **Does a new behavior's test sit above the lowest rung that contains it?**
   Detection: for each new public method on a leaf type,
   `grep -rn '<method>' --include='test_*.py' --include='*_test.py' .` — is it
   exercised directly, or only through an orchestrator's test?
   Violation: leaf behavior reached only from above — add the rung-0 test; the
   orchestrator test keeps only the seam.

5. **Does a test assert on a fake's internals rather than observable behavior?**
   Detection: `grep -rnE 'assert_called|assert_any_call|assert_has_calls|\.call_count|\.call_args|\.mock_calls|\.calls\b' --include='test_*.py' --include='*_test.py' .`;
   also flag assertions reading attributes of a fake instead of querying the
   system under test.
   Violation: the test verifies the double — assert on real state via the public API
   (and the double itself is likely an R6 finding: a `MagicMock` standing in for a
   collaborator that should have had a real in-memory implementation).

6. **Does any test sleep to synchronize?**
   Detection: `grep -rnE 'time\.sleep\(|await asyncio\.sleep\([0-9.]*[1-9]' --include='test_*.py' --include='*_test.py' .`
   Violation: any hit — replace with `Event.wait(timeout)`, `Queue.get(timeout)`,
   `Thread.join(timeout)` or an awaited future; an `await asyncio.sleep(0)` that
   yields the loop once is scheduling, not synchronization, and stays.

7. **Does a mutant survive a leaf type's tests?**
   Detection: for each new or changed leaf package, with `paths_to_mutate` under
   `[tool.mutmut]` naming that package only, `mutmut run` then `mutmut results`;
   skip orchestrators, the top rung and any module that does I/O. `mutmut` not
   installed: propose the install the mechanics bullet describes before hunting; no
   survivors from a run that did not execute is not a pass.
   Violation: any surviving mutant on a leaf module that is not recorded as
   equivalent — a missing parametrize row or dead logic; name the mutant (`mutmut
   show <id>`) and the row that would kill it.
