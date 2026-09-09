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

{{include "rules/R6/canonical-example.md"}}

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
- **Delete the double**: the fake struct in `*{{.TestGlob}}` / `fakes/` / `mocks/` /
  `testutil*` goes with the interface.
- **If a verified cycle exists, fix the layering**: extract the shared vocabulary
  into a lower package both can import, or move the consumer — the dependency arrow
  must point downward.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

{{include "rules/R6/falsifying-questions.md"}}
