---
name: code-designing
description: |
  FORWARD view over rules/ — domain type design and architectural planning for Go code BEFORE it exists.
  Use when planning new features, designing self-validating types, preventing primitive obsession, or when refactoring reveals need for new types.
  Dispatches into the Design guidance sections of rules/R1-R8 and R10-R12.
allowed-tools:
  - Skill(go-linter-driven-development:testing)
---

<objective>
The design phase applied BEFORE code exists. This skill is a thin directional view:
every design principle lives exactly once in `../../rules/` — this protocol says
which rule to open at which design step, and what shape the output takes.

Backward counterpart (fixing code that already fails lint/review): @refactoring.
</objective>

<skill_invocation>
**CRITICAL**: When this skill says "Use @skill-name", you MUST invoke it with the
**Skill tool** — do not just mention it.

| Notation | Skill Tool Call |
|----------|-----------------|
| @testing | `Skill(go-linter-driven-development:testing)` |
</skill_invocation>

<when_to_use>
- Planning a new feature (before writing code)
- Refactoring reveals need for new types (@refactoring escalates here)
- Linter failures that need a design decision, not a mechanical fix:
  - `argument-limit` (>4 params) → design an options struct (grouping data that travels together — score it per `../../rules/R1-primitive-obsession.md`)
  - `function-result-limit` (>3 returns) / `confusing-results` → design a named result type (same R1 scoring)
  - `file-length-limit` (>450 lines) → split juicy types into their own files (juiciness per R1; file-per-type per `../../rules/R5-vertical-slice.md`); a single god type routes to @refactoring's god-object decomposition procedure first
  - Package-size yellow/red zone → re-model with sub-packages *before* the zone escalates (@refactoring `<package_decomposition>`)
- A Phase 4 review CLUSTER (≥2 hunters converging on one anchor —
  @linter-driven-development routes it here) → **cluster-scoped mode**: skip
  `<architecture_scan>` and the user-OK step (acceptance was inherited when the
  findings were accepted); design only the one concept the cluster names — its
  type or dispatch shape (R11), constructor (R2), mutation surface (R12), and
  placement (R4) — so every member finding resolves as a consequence of that one
  design. Return the mini DESIGN PLAN to the caller; @refactoring implements it.
</when_to_use>

<protocol>

<architecture_scan priority="FIRST_STEP">
**Default: vertical slice architecture** — `../../rules/R5-vertical-slice.md`.

Scan the codebase structure: vertical (`internal/feature/{handler,service}.go`) vs
horizontal (`internal/{handlers,services}/feature.go`)?

1. **Pure vertical** → continue the pattern: implement as `internal/<new-feature>/`.
2. **Pure horizontal** → propose starting migration (template in R5's Design
   guidance); implement the new feature as the first vertical slice.
3. **Mixed** → check `docs/architecture/vertical-slice-migration.md`, continue as a slice.

Architecture advises, it doesn't veto (R5's advisory posture). Ask the user:
Option A — vertical slice (recommended); Option B — match the existing pattern
(time pressure and team conventions are valid reasons).
</architecture_scan>

<understand_domain>
What is the problem domain? The main concepts/entities? The invariants and rules?
How does this fit the existing architecture?
</understand_domain>

<maxim_interrogation>
Design happens before a diff exists — no detection command can run yet, so questions
are the tool. Interrogate the plan with `../../maxims.md` (the questions live there,
once; ask them, don't restate them):

- Every function that receives another type's data → **Tell, don't ask**: does the
  decision it makes belong on that type?
- Every planned interface → **The bigger the interface, the weaker the abstraction**:
  could it be one method?
- Every planned type → **Make illegal states unrepresentable** vs **Make the zero
  value useful**: validated domain type (constructor) or mechanism type (useful
  zero)? Pick a family.
- Every planned check → **Parse, don't validate**: does it return a more-typed value
  or a boolean someone must remember?
- Every shared helper → **A little copying is better than a little dependency**: is
  the third strike actually here?

Answers shape the plan; they are never findings. Maxims propose, evidence disposes —
the review phases convict only via rules (`maxims.md`, contract section).
</maxim_interrogation>

<rule_dispatch>
For each concept in the design, open the rule that owns the question and apply its
**Design guidance** section:

| Rule | When designing, apply... |
|------|--------------------------|
| `../../rules/R1-primitive-obsession.md` | Which primitives become types — score every candidate with R1's juiciness scorecard; reject ceremony wrappers (over-abstraction trap). |
| `../../rules/R2-self-validating-types.md` | Constructor-only entry, validation ownership, trusting composed values, nil is not a value, no defensive checks in methods. |
| `../../rules/R3-storifying.md` | Plan orchestration functions as 3–5 named steps at one conceptual level; honest names for mutators. |
| `../../rules/R4-helper-placement.md` | WHERE each helper/type lands — the placement ladder (unexported → feature sub-package → shared domain package). |
| `../../rules/R5-vertical-slice.md` | Package structure and naming: feature slices with roles inside, flatcase domain vocabulary, migration template. |
| `../../rules/R6-test-only-interfaces.md` | Default dependencies to concrete types; an interface must be earned by a second production implementation or a grep-verified import cycle. |
| `../../rules/R7-test-placement.md` | The test plan per type: leaf types 100% unit coverage via public constructors; orchestrators integration-tested over real collaborators. |
| `../../rules/R8-no-globals.md` | Dependencies injected via constructors, `ctx` threaded from callers, globals only at entry points. |
| `../../rules/R10-concurrency-safety.md` | Every planned goroutine gets an owner (stop + wait) and an exit path at construction time; shared state designed with its guard on one type — or designed away via handoff/confinement. |
| `../../rules/R11-conditional-dispatch.md` | How each kind/variant family dispatches: behavior-heavy or open set → interface chosen once at the boundary; single-behavior variance → strategy map; single-site closed enum → one exhaustive switch (named enum per R1). |
| `../../rules/R12-mutation-discipline.md` | Each type's mutation surface: constructors copy slice/map arguments; queries return copies or iterators, never internal references; no setters around validating constructors; query and modifier as separate methods. |
</rule_dispatch>

<design_checklist>
Before presenting the plan, verify against the rules (cite, don't restate):

- [ ] No primitive obsession; every proposed type scored, ceremony rejected (R1)
- [ ] Types are self-validating; composed types trusted, never re-validated (R2)
- [ ] Orchestration planned as a story; most logic pushed into leaf types (R3, R7)
- [ ] **Placement decided** for every helper and type via the ladder — unexported helper vs feature sub-package vs domain package (`../../rules/R4-helper-placement.md`)
- [ ] Vertical slice structure; package names are flatcase domain vocabulary, never roles/containers (R5)
- [ ] No test-only interfaces: every interface has a second production implementation OR breaks a real import cycle, verified by grepping the import direction (detection command in `../../rules/R6-test-only-interfaces.md`); otherwise depend on the concrete type
- [ ] Import direction strictly downward: leaf types ← sub-packages ← parent ← cmd/ (cycle-breaking move in @refactoring `<package_decomposition>`)
- [ ] Dependencies constructor-injected and validated; ctx flows down; no new globals (R8, R2)
- [ ] Every goroutine has an owner and exit path; shared state guarded where it lives, or confined (R10)
- [ ] Every kind/variant family has ONE dispatch owner — interface, strategy map, or a single exhaustive switch; no discriminator inspected in two places (R11)
- [ ] Every validated type's mutation surface is closed: slice/map arguments copied in, internal collections never returned by reference, no unvalidated setters (R12)
</design_checklist>

</protocol>

<output_format>
```
DESIGN PLAN

Feature: [Feature Name]

Core Domain Types (leaf):
- [Type] ([underlying]) — invariant it owns; juiciness verdict (R1)

Orchestrating Types:
- [Type] — dependencies (concrete unless R6-justified), methods

Package Structure:
[feature]/
  ├── [type].go        # each juicy type in its own file
  ├── service.go
  └── handler.go

Placement Decisions (R4):
- [helper/type] → rung 1/2/3 and why

Design Decisions:
- [decision] — rationale, citing the owning rule

Integration Points:
- Consumed by / depends on / events

Next Steps:
1. Create types with validating constructors
2. Write unit tests for each leaf type → use @testing skill
3. Implement orchestrators; integration tests over real collaborators
```
</output_format>

<success_criteria>
Design phase is complete when ALL are true:

- [ ] Architecture pattern analyzed (vertical/horizontal/mixed) and user chose an option
- [ ] Core domain types identified, each with its validation rules and R1 score
- [ ] Placement decision recorded for every new type/helper (R4 ladder)
- [ ] Package structure follows R5 (slices, naming, downward imports)
- [ ] Design checklist answered satisfactorily (every box cites its rule)
- [ ] Design plan presented in the output format above
</success_criteria>
