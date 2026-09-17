# R6 — Test-Only Interfaces

## Principle

A seam that exists only so a test can substitute a double — an interface with one
production implementer, a patched attribute, an injection parameter no production
caller varies — is deleted; depend on the concrete collaborator. Don't create interfaces
until you need them; a test fake is not a need. An interface is justified only by a
real second production implementation or a verified import cycle.

## Why

This is the exact failure that slips past reviews: a reasonable-looking interface
with a comment "explaining" it (usually "avoids an import cycle" or "for testing"),
one production implementation, and a test double as the only other implementer. The
interface adds an indirection every reader must resolve, detaches the consumer from
the real type's documentation and behavior, and — worst — licenses the test to
exercise a hand-written double instead of the real collaborator, so the test proves
nothing about production wiring. A hand-written type that only satisfies a
production interface to stand in for the real collaborator IS a mock, whatever the
file calls it. A "fake" is a real implementation with fake *data* — embedded DB,
in-process HTTP server, temp dir. Orchestrators are tested by wiring their real
collaborators (`R7-test-placement.md`); they never need injection seams carved for
doubles.

## Canonical example

### Before — a seam exists only for a test fake

```text
# service: one production collaborator (the worker store); the abstraction exists for the test
Leaves                       # an interface/protocol with one method: findLatest(id)
Service
    leaves: Leaves

# service test: the ONLY other implementer is a fake
FakeLeaves
    findLatest(id): return self.job
```

In a language with patching instead of interfaces the same smell reads as
`patch("service.Store.findLatest")` on a concrete class: a hand-written stand-in
substituted at the seam, and no production caller ever varies it.

### After — concrete dependency, tested by wiring the real collaborator

```text
# service: concrete; no cycle (the worker package does not import this one)
Service
    leaves: worker.Store

# service test: construct the REAL Store over an embedded database + a fake
# (in-process) external service
testRerun():
    service = newService(realStore, evaluator, ticketClient)   # real objects, fake data
    ... exercise the service's public method, assert on real state
```

The test now covers the seam it claims to cover: the real store's queries run against
a real database. The abstraction, its indirection, and the double are all deleted.

## Design guidance

- **Interfaces are earned by a second production implementation** — an in-memory
  repository that production code can also use, a second backend, a real plug point.
  Until that exists, depend on the concrete type.
- **"For testing" never justifies an interface.** The test's job is to wire real
  collaborators over fake data (real store over embedded DB, real client against an
  in-process HTTP server) — `R7-test-placement.md` places the test; @testing has the harness
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

- **Delete the Test Seam**: replace the interface field, patched attribute or
  injection parameter with the concrete type; delete the interface declaration.
- **Rewrite the test around real collaborators**: construct the real dependency over
  fake data (embedded DB, temp dir, in-process HTTP server) and exercise the consumer's
  public API (@testing for harness patterns; placement per
  `R7-test-placement.md`).
- **Delete the double**: the fake type in `*<test-file suffix>` / `fakes/` / `mocks/` /
  `testutil*` goes with the interface.
- **If a verified cycle exists, fix the layering**: extract the shared vocabulary
  into a lower package both can import, or move the consumer — the dependency arrow
  must point downward.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

Build each search over the language's source files (`detected-language source`); test files are
the ones the repository's test runner picks up.

1. **How many production implementations does each new/changed interface have?**
   Detection: for each method of the interface (protocol, abstract base class, trait),
   search the non-test source files for definitions of that method name — list the
   implementing types.
   Violation: exactly one production implementation — the interface is a candidate
   smell; proceed to Q2.

2. **Is the only other implementer a test double?**
   Detection: search the test files for definitions of the same method names, plus
   the same search over test-support directories (`fakes/`, `mocks/`, `testutil*`,
   `conftest`); in a patching language, search the test files for a patch or
   monkeypatch that targets the collaborator.
   Violation: yes — one production implementation + a double = test-only seam;
   delete it and test the real type.

3. **Would depending on the concrete type cause a REAL import cycle?**
   Detection — do not trust a "cycle" comment; check the import direction: a real
   cycle exists only if the dependency's package imports the consumer's package
   back. Search the dependency's source files for an import of the consumer.
   Violation: no back-import found — the justification is false; the interface
   exists for a test.

4. **Does a consumer take an interface while every production call site passes the
   same concrete type?**
   Detection: search the non-test source files for calls to the consumer's
   constructor — inspect the argument's type at each production call site.
   Violation: one concrete type at every production call site — the interface
   parameter is a seam for doubles; take the concrete type.

5. **Does the diff justify a new interface with "for testing" or "import cycle"?**
   Detection: in the changed files, read the comment lines above each new interface,
   protocol or abstract class for `for test`, `import cycle`, `mock`.
   Violation: any hit — the comment is itself a finding; verify with Q1–Q3 and
   expect deletion.
