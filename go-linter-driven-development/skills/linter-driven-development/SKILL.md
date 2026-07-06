---
name: linter-driven-development
description: |
  META ORCHESTRATOR for any Go code change that should end in a commit (features, bug fixes, refactors).
  WHEN: User requests Go code work (implement, fix, add, refactor), mentions "@ldd"/"ldd", or runs a /go-ldd-* command in a Go project.
  Runs the five-phase workflow: DESIGN → IMPLEMENT (per-behavior TDD loop) → FULL LINT (lint-fixer agent) → REVIEW (per slice) → SHIP.
allowed-tools:
  - Skill(go-linter-driven-development:code-designing)
  - Skill(go-linter-driven-development:testing)
  - Skill(go-linter-driven-development:refactoring)
  - Skill(go-linter-driven-development:pre-commit-review)
  - Skill(go-linter-driven-development:documentation)
  - Task
---

<objective>
Top-level protocol for Go implementation work: five phases, where Phase 2 is a
per-behavior TDD loop. Rule knowledge lives once in `../../rules/` — this skill never
restates it; it sequences the thin skills (which dispatch into the rules) and the
lint-fixer agent, at the cadence each check's economics demand.
</objective>

<triggers>
- User requests Go code work (implement, fix, add, refactor, update, change) and the
  project is Go (`go.mod` or `.go` files present)
- User mentions "ldd" or "@ldd"
- A `/go-ldd-*` command invokes this skill
On trigger, announce: **"Using go-ldd workflow for this Go code work"** and run pre-flight.
</triggers>

<skill_invocation>
"Invoke @skill-name" means: call the **Skill tool**. Never just mention the skill,
never read its file directly.

| Notation | Skill Tool Call |
|----------|-----------------|
| @code-designing | `Skill(go-linter-driven-development:code-designing)` |
| @testing | `Skill(go-linter-driven-development:testing)` |
| @refactoring | `Skill(go-linter-driven-development:refactoring)` |
| @pre-commit-review | `Skill(go-linter-driven-development:pre-commit-review)` |
| @documentation | `Skill(go-linter-driven-development:documentation)` |

The lint-fixer agent is spawned with the **Task tool**:
`subagent_type: "go-linter-driven-development:lint-fixer"`.
</skill_invocation>

<flow>
```
1 DESIGN   @code-designing → DESIGN PLAN → user OK
2 IMPLEMENT — per behavior:
     ┌─> RED      one failing test, lowest rung        (@testing)
     │   GREEN    minimum code to pass — no design work
     │   REFACTOR pkg-scoped lint + rule greps; hits → (@refactoring)
     └── next behavior until all done
3 FULL LINT   ONE run via lint-fixer agent (Task)
     mechanical → FIXED · design → ESCALATED → back to 2's REFACTOR
4 REVIEW   per completed slice: @pre-commit-review → fix → INCREMENTAL re-run
5 SHIP     @documentation → commit summary → user commits
```
</flow>

<pre_flight>
1. **Verify Go project**: `go.mod` in root or parent directories.
2. **Discover commands** (README.md, CLAUDE.md, Makefile, Taskfile.yaml, in that
   order): test + lint commands. Fallbacks: `go test ./...`, `golangci-lint run --fix`.
3. **List the behaviors** this change delivers — each becomes one Phase 2 TDD cycle.
   No plan or unclear scope → Phase 1 produces the plan; unclear intent → ask.
</pre_flight>

<phase_1_design>
Invoke @code-designing. It runs the architecture scan, scores candidate domain types,
records an R4 placement decision for every helper/type, and presents a DESIGN PLAN
for user OK. **Do not start Phase 2 until the user approves the plan** — the RED
tests target this designed public API, which is how the design reaches GREEN.
</phase_1_design>

<phase_2_implement>
One TDD cycle per behavior:

**RED** — write ONE failing test for the behavior. Place it by the composition
ladder — the lowest rung that contains the behavior (@testing,
`<composition_ladder>`). Run it; confirm it fails for the right reason.

**GREEN** — minimum code to pass. Explicitly allowed to be ugly; no design polish in
this step. **Never invoke @code-designing from GREEN**: the design already happened
in Phase 1 and reaches GREEN through the RED test's shape. If GREEN reveals the
design is wrong (a type doesn't fit, a hidden concept emerges): finish the cycle,
then route through REFACTOR → @refactoring → its escalation to @code-designing.
Design revision is a deliberate checkpoint, never a mid-GREEN detour.

**REFACTOR (linter-driven)** — on the code just written:
1. Package-scoped lint (fast): `golangci-lint run ./<pkg>/...`
2. Cheap rule greps: run the detection commands from the **Falsifying questions**
   sections of the `../../rules/R*.md` files relevant to what was written.
Any hit → invoke @refactoring: its `<routing_table>` routes each failure to the
owning rule's Fix pattern. The linter says WHAT to refactor; the rules say HOW.
Fix now — these findings are mechanical and local: cheapest at this moment,
compounding if deferred.

Loop to the next behavior until all behaviors are done.
</phase_2_implement>

<phase_3_full_lint>
Delegate ONE full lint run to the lint-fixer agent (Task, isolated context — the
fix loop's token noise stays out of this conversation). Full-repo lint catches what
package-scoped runs cannot: cross-package issues and whole-file/whole-package rules
(file-length-limit, package-size zones).

The agent returns `FIXED` (mechanical — done) and `ESCALATED` (design-level, each
with a rule route from its embedded routing table). Route every escalation back
through the Phase 2 REFACTOR step — invoke @refactoring with the routes; **never
auto-redesign here**. Package-size escalations follow @refactoring
`<package_decomposition>` (decomposition lands in its own commit). Repeat Phase 3
until the agent reports `LINT STATUS: green`.
</phase_3_full_lint>

<phase_4_review>
Per completed vertical slice (multi-slice work reviews each slice as it completes),
invoke @pre-commit-review — it orchestrates parallel rule hunters plus the
over-abstraction skeptic; it spawns agents and reports, **never edits**.

NOT mid-implementation (its `<timing>` contract): GREEN-step code is supposed to
look under-designed, so reviewing it produces false positives — and the hunters'
fresh-context value only pays on finished work. The REFACTOR-step greps are the
mid-implementation net; this pass is the verification net.

Findings return categorized (Bugs / Design Debt / Readability Debt / Polish), all
advisory. Fix bugs and user-accepted findings via @refactoring, then re-invoke
@pre-commit-review in INCREMENTAL mode until the delta reports clean.
</phase_4_review>

<phase_5_ship>
1. Invoke @documentation: package/type godoc, testable examples, feature docs.
2. Present the ship summary: tests green (`go test ./...`), lint green (Phase 3),
   review delta (Phase 4), files changed, suggested commit message.
3. User decides: commit as-is · fix deferred advisory findings first · defer.
</phase_5_ship>

<success_criteria>
- [ ] Design plan user-approved before the first RED
- [ ] Every behavior completed a RED → GREEN → REFACTOR cycle
- [ ] Package-scoped lint + rule greps clean after each cycle
- [ ] lint-fixer reported `LINT STATUS: green`; all escalations resolved via @refactoring
- [ ] @pre-commit-review INCREMENTAL delta clean, or findings explicitly deferred by user
- [ ] @documentation done; commit summary presented and user chose an action
</success_criteria>
