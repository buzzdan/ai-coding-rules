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

{{include "rules/R7/canonical-example.md"}}

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

{{include "rules/R7/falsifying-questions.md"}}
