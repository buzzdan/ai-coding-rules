# R6 — Test-Only Interfaces

## Principle

An interface whose only non-test implementation is a single concrete type exists to
enable a mock — delete it and depend on the concrete type. Don't create interfaces
until you need them; a test fake is not a need. An interface is justified only by a
real second production implementation or a verified import cycle.

## Why

This is the exact failure that slips past reviews: a reasonable-looking interface
with a comment "explaining" it (usually "avoids an import cycle" or "for testing"),
one production implementation, and a test double as the only other implementer. The
interface adds an indirection every reader must resolve, detaches the consumer from
the real type's documentation and behavior, and — worst — licenses the test to
exercise a hand-written double instead of the real collaborator, so the test proves
nothing about production wiring. A hand-written struct that only satisfies a
production interface to stand in for the real collaborator IS a mock, whatever the
file calls it. A "fake" is a real implementation with fake *data* — embedded DB,
`httptest` server, temp dir. Orchestrators are tested by wiring their real
collaborators (`R7-test-placement.md`); they never need injection seams carved for
doubles.

## Canonical example

### Before — interface exists only for a test fake

```go
// service.go — one prod impl (*worker.Store); the interface exists for the test
type Leaves interface {
    FindLatest(ctx context.Context, id ID) (Job, error)
}

type Service struct { leaves Leaves }

// service_test.go — the ONLY other implementer is a mock
type fakeLeaves struct{ job Job }

func (f *fakeLeaves) FindLatest(context.Context, ID) (Job, error) { return f.job, nil }
```

### After — concrete dependency, tested by wiring the real collaborator

```go
// service.go — concrete; no cycle (the worker package does not import this one)
type Service struct { leaves *worker.Store }

// service_test.go — construct the REAL Store over embedded Postgres + a fake
// (httptest) external service
func (s *Suite) TestRerun() {
    svc, _ := NewService(s.store, s.evaluator, s.jiraClient) // real objects, fake data
    // ... exercise svc's public method, assert on real state
}
```

The test now covers the seam it claims to cover: the real `Store`'s queries run
against a real database. The interface, its indirection, and the double are all
deleted.

## Design guidance

- **Interfaces are earned by a second production implementation** — an in-memory
  repository that production code can also use, a second backend, a real plug point.
  Until that exists, depend on the concrete type.
- **"For testing" never justifies an interface.** The test's job is to wire real
  collaborators over fake data (real store over embedded DB, real client against
  `httptest`) — `R7-test-placement.md` places the test; @testing has the harness
  patterns.
- **"Avoids an import cycle" is a claim, not a fact — verify it.** A real cycle
  exists only if the dependency's package imports the consumer's package back. If
  the grep (below) shows no back-import, the comment is cover for a test seam.
- **A real cycle is a layering bug, not an interface opportunity.** Move the package
  so the dependency direction is downward; don't invert the arrow with an interface
  whose only purpose is to break the cycle a double rides in on.
- **When an interface is genuinely needed**, define it at the point of use (in the
  consumer's package), keep it small and cohesive, and expect every implementation
  to be production code. The worked case of an *earned* interface — multiple
  production implementations replacing a growing type switch, sealed by an
  unexported method: `../examples/switch-to-polymorphism.md` (dispatch discipline:
  `R11-conditional-dispatch.md`).

## Fix pattern

- **Inline the interface**: replace the interface field/parameter with the concrete
  type; delete the interface declaration.
- **Rewrite the test around real collaborators**: construct the real dependency over
  fake data (embedded DB, temp dir, `httptest` server) and exercise the consumer's
  public API (@testing for harness patterns; placement per
  `R7-test-placement.md`).
- **Delete the double**: the fake struct in `*_test.go` / `fakes/` / `mocks/` /
  `testutil*` goes with the interface.
- **If a verified cycle exists, fix the layering**: extract the shared vocabulary
  into a lower package both can import, or move the consumer — the dependency arrow
  must point downward.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **How many production implementations does each new/changed interface have?**
   Detection: for each method of the interface,
   `grep -rn 'func (.*) <Method>(' --include='*.go' . | grep -v _test.go` — list the
   implementing types.
   Violation: exactly one production implementation — the interface is a candidate
   smell; proceed to Q2.

2. **Is the only other implementer a test double?**
   Detection: `grep -rn 'func (.*) <Method>(' --include='*_test.go' .` plus the same
   grep over test-support packages (`fakes/`, `mocks/`, `testutil*`).
   Violation: yes — one production implementation + a double = test-only interface;
   delete it and test the real type.

3. **Would depending on the concrete type cause a REAL import cycle?**
   Detection — do not trust a "cycle" comment; check the import direction:
   ```bash
   # a real cycle exists only if the dependency package imports the consumer back:
   grep -rn '"<module>/<consumer-pkg>"' <dependency-pkg-dir>/*.go   # no match ⇒ no cycle ⇒ interface unjustified
   ```
   Violation: no back-import found — the justification is false; the interface
   exists for a test.

4. **Does a consumer take an interface while every production call site passes the
   same concrete type?**
   Detection: `grep -rn 'New<Consumer>(' --include='*.go' . | grep -v _test.go` —
   inspect the argument's type at each production call site.
   Violation: one concrete type at every production call site — the interface
   parameter is a seam for doubles; take the concrete type.

5. **Does the diff justify a new interface with "for testing" or "import cycle"?**
   Detection: `grep -rn -B2 'interface {' <changed files> | grep -iE 'for test|import cycle|mock'`
   Violation: any hit — the comment is itself a finding; verify with Q1–Q3 and
   expect deletion.
