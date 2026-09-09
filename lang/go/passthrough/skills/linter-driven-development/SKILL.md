---
name: linter-driven-development
description: |
  META ORCHESTRATOR for any Go code change that should end in a commit (features, bug fixes, refactors).
  WHEN: User requests Go code work (implement, fix, add, refactor), mentions "@ldd"/"ldd", or runs a /go-ldd-* command in a Go project.
  Runs the five-phase workflow (PREPARE is an autonomous sub-phase, 1.5): DESIGN → PREPARE → IMPLEMENT (per-behavior TDD loop) → FULL LINT (lint-fixer agent) → REVIEW (per slice) → SHIP.
allowed-tools:
  - Skill(go-linter-driven-development:code-designing)
  - Skill(go-linter-driven-development:testing)
  - Skill(go-linter-driven-development:refactoring)
  - Skill(go-linter-driven-development:pre-commit-review)
  - Skill(go-linter-driven-development:documentation)
  - Agent
---

<objective>
Top-level protocol for Go implementation work: five phases plus the autonomous
PREPARE sub-phase (1.5), where Phase 2 is a per-behavior TDD loop. Rule knowledge lives once in `../../rules/` — this skill never
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

The lint-fixer agent is spawned with the **Agent tool**:
`subagent_type: "go-linter-driven-development:lint-fixer"`.
</skill_invocation>

<flow>
```
1 DESIGN   @code-designing → DESIGN PLAN → user OK
1.5 PREPARE   survey plan's touch points → four gates decide autonomously →
     (@refactoring, preparatory mode) → prep commit(s) · PREPARATION LOG (record, no stop)
2 IMPLEMENT — per behavior:
     ┌─> RED      one failing test, lowest rung        (@testing)
     │            test resists? → prep signal → @refactoring (preparatory) → re-enter RED
     │   GREEN    minimum code to pass — no design work
     │   REFACTOR pkg-scoped lint + rule greps; hits → (@refactoring)
     └── next behavior until all done
3 FULL LINT   ONE run via lint-fixer agent (Agent tool)
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

<phase_1_5_prepare>
Preparatory refactoring (Fowler: "make the change easy, then make the easy change"):
reshape what the approved plan is about to touch, BEFORE the first RED, so the
feature lands as add-only. Runs **autonomously** — the four gates below decide;
this phase never asks the user.

**Survey**: for each file/package the DESIGN PLAN touches (integration points,
functions it extends, packages receiving new code), run the rule detection greps from
the `../../rules/R*.md` Falsifying questions, scoped to those files only. Same
commands as the REFACTOR step, different premise: this code is probably lint-green
and can still be hostile to the plan.

**Four gates per finding — all mechanical, no user questions:**

1. **MULTIPLY** — would landing the plan add an instance of this violation or force a
   workaround (a new case in an already-duplicated switch, R11; new behavior on a raw
   primitive, R1; a new step in an at-limit function, R3; new code testable only by
   mutating a global, R8)? No → not preparation; leave it for Phase 4's advisory
   report.
2. **SAFE** — are the paths to reshape covered (`go test -cover` on the touched
   packages)? Uncovered → write characterization tests through the public API first
   (@testing); they are the move's safety net and keep their value after. When the
   missing test seam IS the finding (globals block testing), the prep move creates
   the seam — R8's Extract Clean Island exists for exactly this.
3. **BOUNDED** — effort S/M (hunter scale) → proceed. L → defer to Phase 4's report
   as `PREP-DEFERRED`, UNLESS gate 2 showed the feature cannot be tested at all
   without it — then it is not preparation but a design-plan gap: return to Phase 1.
4. **SKEPTICIZED** — any prep move that creates a type/interface/package is judged by
   the `overabstraction-skeptic` (Agent tool; payload per @pre-commit-review step 3), with
   one sharpening in the spawn prompt: the justification is the approved plan in
   hand, not an imagined future — score the extraction as if the feature already
   existed. REFUTED → apply the cheaper alternative or defer.

**Apply** the survivors via @refactoring (`<preparatory_mode>`); full test suite and
lint green after every move; land the prep work as its own commit(s) before the first
RED — the Two Hats at commit granularity, and the reviewer sees reshaping and feature
separately.

**Emit a PREPARATION LOG** — a record, not a question; the loop continues:

```
PREPARATION LOG
Touch points surveyed: [files] · findings: N
Applied: [rule → move → commit] (gates: multiply ✓ safe ✓ bounded ✓ skeptic ✓/n-a)
Deferred to Phase 4: [finding — failed gate]
Feature landing shape after prep: [add-only / near-add-only / unchanged]
```

Zero findings passing the gates is the common case — say so in one line and move on.

Inverse trap: reshaping files the plan does not touch is litter-pickup wearing prep's
clothes — a different activity on a different budget; pre-building abstractions this
plan does not need is speculative generality — gate 4 exists to kill it.
</phase_1_5_prepare>

<phase_2_implement>
One TDD cycle per behavior:

**RED** — write ONE failing test for the behavior. Place it by the composition
ladder — the lowest rung that contains the behavior (@testing,
`<composition_ladder>`). Run it; confirm it fails for the right reason.

If the test *resists* — fixture surgery, mutating globals to reach the behavior,
driving three layers to observe one seam — do not force it: that friction is a prep
signal Phase 1.5's survey missed. Suspend the cycle, route the friction through the
same four PREPARE gates, apply via @refactoring (`<preparatory_mode>`), land the prep
commit, re-enter RED. Autonomous, like Phase 1.5 — no user question.

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
Delegate ONE full lint run to the lint-fixer agent (Agent tool, isolated context — the
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
advisory. Fix bugs and user-accepted findings via @refactoring — except accepted R9
(documentation-network) findings, whose fixer is @documentation — then re-invoke
@pre-commit-review in INCREMENTAL mode until the delta reports clean.

**Cluster routing**: report entries marked 🔗 CLUSTER (≥2 hunters converging on one
anchor) are fixed design-first, never member-by-member — partial fixes undo each
other (R1 names an enum that R11's move then replaces; R2 places validation that
R11's move relocates). Invoke @code-designing in cluster-scoped mode (it skips the
architecture scan and the user-OK gate — acceptance was inherited when the cluster's
findings were accepted; output is a mini DESIGN PLAN for the one concept the cluster
names), then @refactoring implements that plan; the member findings resolve as
consequences of one design. Singleton findings route directly to @refactoring as
before.
</phase_4_review>

<phase_5_ship>
1. Invoke @documentation (FEATURE mode): godoc + feature docs, wired into the
   documentation network (index line, edges both directions, root import), plus its
   R9 self-check over the diff and its comment-critic critique loop (the critic
   reviews every comment in the diff against R9's three-test standard;
   @documentation applies the verdicts and re-critiques once — R3 routes from the
   critic go back through @refactoring like any R3 finding).
2. Present the ship summary: tests green (`go test ./...`), lint green (Phase 3),
   review delta (Phase 4), files changed, suggested commit message.
3. User decides: commit as-is · fix deferred advisory findings first · defer.
</phase_5_ship>

<success_criteria>
- [ ] Design plan user-approved before the first RED
- [ ] PREPARE ran its survey over the plan's touch points; every applied prep move
      passed all four gates and landed in its own commit; PREPARATION LOG emitted
- [ ] Every behavior completed a RED → GREEN → REFACTOR cycle
- [ ] Package-scoped lint + rule greps clean after each cycle
- [ ] lint-fixer reported `LINT STATUS: green`; all escalations resolved via @refactoring
- [ ] @pre-commit-review INCREMENTAL delta clean, or findings explicitly deferred by user
- [ ] @documentation (FEATURE mode) done — docs wired into the network, R9 self-check
      clean, comment-critic critique loop applied and confirmed clean (or remainder
      reported); commit summary presented and user chose an action
</success_criteria>
