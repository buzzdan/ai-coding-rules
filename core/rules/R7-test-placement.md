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

{{include "rules/R7/canonical-example.md"}}

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
{{include "rules/R7/mutation-mechanics.md"}}
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
{{include "rules/R7/mechanics.md"}}
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

{{include "rules/R7/falsifying-questions.md"}}
