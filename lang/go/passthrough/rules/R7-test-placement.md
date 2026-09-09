# R7 — Test Placement

## Principle

Every behavior is tested at the lowest rung of the composition ladder that contains
it: rung 0 is pure leaf types (unit tests with literal inputs, 100% coverage, public
API only, `pkg_test` package); each rung above adds exactly one real production
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
same reason: a conditional inside `t.Run` means one case is really two, and a test
asserting on a fake's internals verifies the double, not the system. The full
composition ladder and harness patterns live in @testing; this rule is the placement
and review contract.

## Canonical example

### Before — anti-patterns stacked

```go
package user // same package — can reach privates

func TestValidateEmailInternal(t *testing.T) { // testing a private
    assert.True(t, validateEmailInternal("test@example.com"))
}

func TestCreateUser(t *testing.T) { // doubles instead of collaborators
    mockRepo := &MockRepository{}
    mockRepo.On("Save", mock.Anything).Return(nil)

    svc := &UserService{Repo: mockRepo} // literal construction, no constructor
    err := svc.CreateUser("123", "test@example.com")
    assert.NoError(t, err)
    mockRepo.AssertExpectations(t) // asserts on the fake, not on behavior
}

func TestAsyncOperation(t *testing.T) {
    go doAsyncWork()
    time.Sleep(100 * time.Millisecond) // flaky
    assert.True(t, workCompleted)
}
```

### After — right rung, real collaborators, observable behavior

```go
package user_test // external package — public API only

func TestService_CreateUser(t *testing.T) {
    repo := user.NewInMemoryRepository() // real implementation, fake data
    emailer := user.NewTestEmailer()

    svc, err := user.NewUserService(repo, emailer)
    require.NoError(t, err)

    err = svc.CreateUser(context.Background(), testUser)
    require.NoError(t, err)

    retrieved, err := svc.GetUser(context.Background(), testUser.ID) // verify via public API
    require.NoError(t, err)
    assert.Equal(t, testUser.Email, retrieved.Email)
}

func TestAsyncOperation(t *testing.T) {
    done := make(chan struct{})
    go func() { doAsyncWork(); close(done) }()

    select {
    case <-done:
    case <-time.After(1 * time.Second):
        t.Fatal("timeout waiting for async work")
    }
}
```

Email validation itself is a leaf behavior — it belongs one rung down, as a unit
test on `ParseEmail` with literal strings, not inside the service test and not as a
private-function test.

## Design guidance

- **Leaf types (rung 0)**: 100% unit coverage; constructed only through their public
  constructors; inputs are literals; `pkg_test` package so privates are unreachable.
  Most of the codebase's logic should live here (`R1-primitive-obsession.md`).
- **Orchestrating types**: integration-style tests wiring real collaborators — real
  store over an embedded DB, real client against `httptest` — never
  interface-injected doubles (`R6-test-only-interfaces.md`). They cover the seams;
  overlapping a leaf's happy path while doing so is acceptable.
- **Fake only the true external boundary** — the API you don't control — and fake it
  with a real server speaking the real protocol (`httptest`), wired via URL/config.
- **Complexity 1 inside every `t.Run`**: no if/else, no switch. The `wantErr bool`
  pattern is the canonical violation — it folds success and error cases into one
  table and pays with a conditional. Split into `TestX_Success` and `TestX_Error`
  functions.
- **The urge to test a private is a placement signal**, never a license: it means
  the helper deserves its own package (`R4-helper-placement.md`), where its public
  API is legitimately testable.
- **Mechanics**: named struct fields in every table (the linter reorders fields);
  no `time.Sleep` — channels or wait groups; testify suites only for real
  infrastructure setup, not plain unit tests.
- Full ladder, harness patterns, and dependency levels (in-memory → binary →
  containers): @testing.

## Fix pattern

- **Move the behavior down a rung**: rewrite the big-object test as a leaf unit test
  with literal inputs; if the leaf doesn't exist yet, that is an R1/R3 extraction
  first (`../examples/storify-leaf-type.md` shows the pair).
- **Split `wantErr` tables**: one `_Success` function asserting values, one `_Error`
  function asserting errors — complexity 1 in both.
- **Replace doubles with real collaborators**: delete the mock, wire the real
  dependency over fake data (`R6-test-only-interfaces.md`; @testing for harnesses).
- **Replace sleep with synchronization**: channel + `select`/timeout, or
  `sync.WaitGroup`.
- **Delete private-function tests**: cover through the parent's public API, or
  promote the helper (`R4-helper-placement.md`).

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

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
