# R7 — Test Placement

## Principle

Every behavior is tested at the lowest rung of the composition ladder that contains
it: rung 0 is pure leaf types (unit tests with literal inputs, 100% coverage, public
API only, imported as a consumer would); each rung above adds exactly one real production
layer; only the true external boundary is ever faked. Orchestrating types get
integration-style tests that cover the seams between their real collaborators — some
overlap with leaf coverage is fine; leaf behavior tested *only* from above is not. On
a leaf type, coverage is the floor and the mutation score is the claim: a leaf's
tests must fail when its logic is changed, and a mutant that survives them is a
missing row or dead logic.

## Why

A behavior tested above its lowest rung pays for machinery the behavior doesn't
need: big-object construction, harnesses, fakes — and when it fails, the failure
points at the orchestration, not at the leaf that owns the bug. Tested at its rung,
the same behavior is a table of literals that pinpoints its owner. The placement
rule is also the enforcement arm of the design rule: if a leaf behavior *cannot* be
tested with literals, the logic is trapped in an orchestrator and R1/R3 extraction
is owed (`R1-primitive-obsession.md` Stage 3 shows the payoff — a K8s fixture test
collapsing into a slice-literal test). Discipline inside the tests matters for the
same reason: a conditional inside a table case means one case is really two, and a test
asserting on a fake's internals verifies the double, not the system. Line coverage
cannot tell either of those apart from a real test: a table that runs every line and
asserts nothing scores 100%. Mutation testing checks the claim coverage only
implies — flip a comparison, negate a branch, drop a statement, and rerun the suite;
a mutant the suite lets live marks logic no test pins down. It is worth its
runtime exactly where the logic is: rung 0, where the tests are literal tables and
the suite is fast. Orchestrators are not mutated; their seams are covered by wiring,
and a mutation run over them pays the harness cost per mutant for findings that
belong to a leaf anyway. The full
composition ladder and harness patterns live in @testing; this rule is the placement
and review contract.

## Canonical example

### Before — anti-patterns stacked

```python
from app.user.service import _validate_email_internal, UserService   # private import


def test_validate_email_internal() -> None:                # testing a private
    assert _validate_email_internal("test@example.com")


@patch("app.user.service.Repository")                      # a double instead of the collaborator
def test_create_user(repo_cls: MagicMock) -> None:
    svc = UserService(repo_cls.return_value)
    svc.create_user("123", "test@example.com")
    repo_cls.return_value.save.assert_called_once()        # asserts on the fake, not on behaviour


@pytest.mark.parametrize(
    ("raw", "expect_err"),                                  # success and error fused
    [("a@b.io", False), ("", True)],
)
def test_parse_email(raw: str, expect_err: bool) -> None:
    if expect_err:                                          # a conditional inside a case
        with pytest.raises(ValueError):
            Email.parse(raw)
    else:
        assert Email.parse(raw).domain == "b.io"


def test_async_operation() -> None:
    threading.Thread(target=do_async_work).start()
    time.sleep(0.1)                                         # flaky
    assert work_completed
```

### After — right rung, real collaborators, observable behaviour

```python
from app import user                                       # imported as a consumer would


def test_service_create_user(tmp_path: Path) -> None:
    repo = user.FileRepository(tmp_path / "users.json")    # real implementation, fake data
    emailer = user.RecordingEmailer()

    svc = user.UserService(repo, emailer)
    svc.create_user(TEST_USER)

    assert svc.get_user(TEST_USER.id).email == TEST_USER.email   # verify via the public API


@pytest.mark.parametrize(
    ("raw", "domain"),
    [pytest.param("a@b.io", "b.io", id="plain"), pytest.param("A@B.IO", "b.io", id="lower-cased")],
)
def test_parse_email_success(raw: str, domain: str) -> None:
    assert user.Email.parse(raw).domain == domain


@pytest.mark.parametrize("raw", [pytest.param("", id="empty"), pytest.param("no-at", id="no-at")])
def test_parse_email_error(raw: str) -> None:
    with pytest.raises(ValueError):
        user.Email.parse(raw)


def test_async_operation() -> None:
    done = threading.Event()
    threading.Thread(target=lambda: (do_async_work(), done.set())).start()

    assert done.wait(timeout=1.0), "timeout waiting for async work"
```

Email validation itself is a leaf behaviour — it belongs one rung down, as a unit
test on `Email.parse` with literal strings, not inside the service test and not as a
private-function test. The two `parametrize` tables are the split the rule asks for:
one function asserts values, one asserts the raise, and neither case body branches.

## Design guidance

- **Leaf types (rung 0)**: 100% unit coverage; constructed only through their public
  constructors; inputs are literals; imported as a consumer would, so privates are
  unreachable.
  Most of the codebase's logic should live here (`R1-primitive-obsession.md`).
- **Mutation score on leaf types only**: once a leaf's tests cover it, run the
  mutation tool over that leaf's package — never over orchestrators, the top rung or
  the whole module — and triage every survivor: a *missing row* (add the literal that
  tells the mutant from the original), *dead logic* (the mutant is unreachable —
  delete the code, not the mutant), or an *equivalent mutant* (the change is
  behavior-preserving — note it in the test file, once, with the reason). No survivor
  is left untriaged; scope the run to the leaf packages the change touched so it
  stays as fast as the tables it checks.
- **Mutation mechanics**: `mutmut run` with `[tool.mutmut]` in `pyproject.toml` listing
  the leaf packages under `paths_to_mutate` — never the whole `src/` tree — after the
  leaf's tests are green there and after each fix; `mutmut results` lists the
  survivors to triage and `mutmut show <id>` prints one mutant's diff. Mutation runs
  reuse the repository's pytest, never a second runner.
- **Orchestrating types**: integration-style tests wiring real collaborators — real
  store over an embedded DB, real client against an in-process HTTP server — never
  interface-injected doubles (`R6-test-only-interfaces.md`). They cover the seams;
  overlapping a leaf's happy path while doing so is acceptable.
- **Fake only the true external boundary** — the API you don't control — and fake it
  with a real server speaking the real protocol, wired via URL/config.
- **Complexity 1 inside every test case**: no if/else, no switch. A success-or-error
  flag in one table is the canonical violation — it folds success and error cases
  into one table and pays with a conditional. Split into a success function and an
  error function.
- **The urge to test a private is a placement signal**, never a license: it means
  the helper deserves its own package (`R4-helper-placement.md`), where its public
  API is legitimately testable.
- **Mechanics**: `pytest.param(..., id=...)` on every row so a failure names its
  case, and named tuple fields rather than positional tuples when a row carries more
  than two values; no `time.sleep` — `Event.wait(timeout)`, `Queue.get(timeout)` or an
  awaited future; fixtures only for real infrastructure setup (a temp directory, a
  fake server, a database), never to hide the literal a test should show; import the
  package as a consumer would (`from app import user`), never a `_private` name;
  success and error cases in separate `test_x_success`/`test_x_error` functions,
  never one table with an `expect_err` column and a branch on it.
- Full ladder, harness patterns, and dependency levels (in-memory → binary →
  containers): @testing.

## Fix pattern

- **Move the behavior down a rung**: rewrite the big-object test as a leaf unit test
  with literal inputs; if the leaf doesn't exist yet, that is an R1/R3 extraction
  first (`../examples/storify-leaf-type.md` shows the pair).
- **Split Success and Error Tables**: one function asserting values, one asserting
  errors — complexity 1 in both.
- **Kill the surviving mutant**: add the table row whose literal input distinguishes
  the mutant from the original; when no input can, the mutated code was dead — delete
  it; when the mutant is provably equivalent, record why beside the tests.
- **Replace doubles with real collaborators**: delete the mock, wire the real
  dependency over fake data (`R6-test-only-interfaces.md`; @testing for harnesses).
- **Replace sleep with synchronization**: an event, channel or wait primitive with a
  timeout, never a fixed pause.
- **Delete private-function tests**: cover through the parent's public API, or
  promote the helper (`R4-helper-placement.md`).

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

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
   skip orchestrators, the top rung and any module that does I/O.
   Violation: any surviving mutant on a leaf module that is not recorded as
   equivalent — a missing parametrize row or dead logic; name the mutant (`mutmut
   show <id>`) and the row that would kill it.
