# R7 — Test Placement

## Principle

Every behavior is tested at the lowest rung of the composition ladder that contains
it: rung 0 is pure leaf types (unit tests with literal inputs, 100% coverage, public
API only, imported as a consumer would); each rung above adds exactly one real production
layer; only the true external boundary is ever faked. Orchestrating types get
integration-style tests that cover the seams between their real collaborators — some
overlap with leaf coverage is fine; leaf behavior tested *only* from above is not.

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
asserting on a fake's internals verifies the double, not the system. The full
composition ladder and harness patterns live in @testing; this rule is the placement
and review contract.

## Canonical example

### Before — anti-patterns stacked

```text
# same module as the code under test — can reach privates
testValidateEmailInternal():                 # testing a private
    assert validateEmailInternal("test@example.com")

testCreateUser():                            # doubles instead of collaborators
    mockRepo = Mock()
    mockRepo.save.returns(ok)
    service = UserService(repo = mockRepo)   # literal construction, no constructor
    service.createUser("123", "test@example.com")
    mockRepo.save.assertCalled()             # asserts on the fake, not on behavior

testAsyncOperation():
    startAsyncWork()
    sleep(100 ms)                            # flaky
    assert workCompleted
```

### After — right rung, real collaborators, observable behavior

```text
# imported as a consumer would — public API only
testService_CreateUser():
    repo = user.newInMemoryRepository()      # real implementation, fake data
    emailer = user.newTestEmailer()
    service = user.newUserService(repo, emailer)   # fails → the test fails here

    service.createUser(testUser)
    retrieved = service.getUser(testUser.id) # verify via public API
    assert retrieved.email == testUser.email

testAsyncOperation():
    done = an event the work signals when it finishes
    startAsyncWork(then: done.set())
    assert done.wait(timeout = 1 s)          # a timeout, never a fixed pause
```

Email validation itself is a leaf behavior — it belongs one rung down, as a unit
test on `parseEmail` with literal strings, not inside the service test and not as a
private-function test.

## Design guidance

- **Leaf types (rung 0)**: 100% unit coverage; constructed only through their public
  constructors; inputs are literals; imported as a consumer would, so privates are
  unreachable.
  Most of the codebase's logic should live here (`R1-primitive-obsession.md`).
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
- **Mechanics**: name every table field; no fixed pauses — wait on the event; test
  suites and fixtures only for real infrastructure setup, not plain unit tests; the
  repository's own test framework, never a second one.
- Full ladder, harness patterns, and dependency levels (in-memory → binary →
  containers): @testing.

## Fix pattern

- **Move the behavior down a rung**: rewrite the big-object test as a leaf unit test
  with literal inputs; if the leaf doesn't exist yet, that is an R1/R3 extraction
  first (`../examples/storify-leaf-type.md` shows the pair).
- **Split Success and Error Tables**: one function asserting values, one asserting
  errors — complexity 1 in both.
- **Replace doubles with real collaborators**: delete the mock, wire the real
  dependency over fake data (`R6-test-only-interfaces.md`; @testing for harnesses).
- **Replace sleep with synchronization**: an event, channel or wait primitive with a
  timeout, never a fixed pause.
- **Delete private-function tests**: cover through the parent's public API, or
  promote the helper (`R4-helper-placement.md`).

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

Test files are the ones the repository's test runner picks up (`*<test-file suffix>`, a
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
   import of a private module or an unexported name).
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
