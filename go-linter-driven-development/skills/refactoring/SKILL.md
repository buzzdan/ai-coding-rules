---
name: refactoring
description: |
  BACKWARD view over rules/ — routes linter and review failures to the rule whose Fix pattern owns the repair.
  Use when linter fails with complexity issues (cyclomatic, cognitive, maintainability) or when code feels hard to read/maintain.
  Also runs PREPARATORY mode: reshape code an approved plan touches, before the first RED, so the feature lands add-only.
  Applies storifying, type extraction, function extraction, conditional-dispatch, and mutation-discipline patterns via rules/R1-R8 and R10-R12.
allowed-tools:
  - Skill(go-linter-driven-development:code-designing)
  - Skill(go-linter-driven-development:testing)
  - Skill(go-linter-driven-development:pre-commit-review)
---

<objective>
Fix code that already fails lint or review. This skill is a thin directional view:
every fix pattern lives exactly once in `../../rules/` — this protocol routes each
failure to its owning rule, sequences multi-rule work via `reference.md`, and loops
until green. Operates autonomously — no user confirmation between patterns.

Forward counterpart (designing before code exists): @code-designing.
</objective>

<skill_invocation>
**CRITICAL**: When this skill says "Invoke @skill-name", you MUST invoke it with the
**Skill tool** — do not just mention it.

| Notation | Skill Tool Call |
|----------|-----------------|
| @code-designing | `Skill(go-linter-driven-development:code-designing)` |
| @testing | `Skill(go-linter-driven-development:testing)` |
| @pre-commit-review | `Skill(go-linter-driven-development:pre-commit-review)` |
</skill_invocation>

<routing_table>
Normative linter→rule routing. (The lint-fixer agent embeds a compact copy of this
table in `../../agents/lint-fixer.md` — keep them consistent.)

| Linter failure | Route |
|---|---|
| `gocyclo` / `cyclop` | `../../rules/R3-storifying.md` |
| `gocognit` | `../../rules/R3-storifying.md` |
| `funlen` | `../../rules/R3-storifying.md` |
| `nestif` | `../../rules/R3-storifying.md` |
| `maintidx` | `../../rules/R3-storifying.md` + `../../rules/R1-primitive-obsession.md` |
| `dupl` | `../../rules/R1-primitive-obsession.md` (extract shared type/logic); duplicated blocks that switch on the same kind/type discriminator → `../../rules/R11-conditional-dispatch.md` |
| `exhaustive` (missing enum cases) | `../../rules/R11-conditional-dispatch.md` — handle the case at the single dispatch site; a second switch appearing is the R11 violation itself |
| revive `file-length-limit`; package-size hook failures (`hooks/check-package-sizes.sh`) | `../../rules/R5-vertical-slice.md` — mechanics in `<file_and_package_routing>` below |
| `gochecknoglobals` / `gochecknoinits` | `../../rules/R8-no-globals.md` |
| `ireturn` / interface lint on single-impl interfaces | `../../rules/R6-test-only-interfaces.md` |
| `go test -race` failures; `govet` `copylocks` | `../../rules/R10-concurrency-safety.md` |
| `wrapcheck`, `errcheck`, `goconst`, revive `early-return`, renames | Mechanical — fix directly (`fmt.Errorf("context: %w", err)`, handle the error, extract constant, invert & return early). Enum-shaped `goconst` strings → R1's "Name enum strings" move. |
</routing_table>

<pattern_index>
Each named refactoring move is owned by one rule's **Fix pattern** section — apply it
from there, never from memory:

| Move | Owner |
|------|-------|
| Extract Function (named after the comment), Early Returns, Honest Rename, Extract Leaf Type | `../../rules/R3-storifying.md` |
| Replace Primitive with Domain Type, Extract Collection Type, Replace Sentinel with comma-ok, Name enum strings, Over-abstraction rejection | `../../rules/R1-primitive-obsession.md` |
| Add validating constructor, Hoist method checks, Delete re-validation, Replace nil returns | `../../rules/R2-self-validating-types.md` |
| Demote helper (rung 1), Promote to feature/domain package (rungs 2–3), Split policy from vocabulary | `../../rules/R4-helper-placement.md` |
| Slice out a feature, Rename layer files by role, Split a generic package by owner | `../../rules/R5-vertical-slice.md` |
| Inline the interface, Rewrite test around real collaborators, Delete the double | `../../rules/R6-test-only-interfaces.md` |
| Move test down a rung, Split `wantErr` tables, Replace sleep with synchronization | `../../rules/R7-test-placement.md` |
| Extract Clean Island, Push Global Up One Level, Replace `init()` with constructor, Thread `ctx` | `../../rules/R8-no-globals.md` |
| Inject the Exit Path, Make the Goroutine Joinable, Extract Synchronized Owner, Replace Sleep with Timer Select, Delete Unearned Guards | `../../rules/R10-concurrency-safety.md` |
| Replace Duplicated Switch with Interface Dispatch, Replace If-Chain with Strategy Map, Introduce Null Object, Split Flag Argument, Keep the Single Exhaustive Switch | `../../rules/R11-conditional-dispatch.md` |
| Copy on the Way In, Copy on the Way Out / Encapsulate Collection, Separate Query from Modifier, Remove Setting Method, Split Variable | `../../rules/R12-mutation-discipline.md` |

**Multi-rule procedures** (sequencing, god-object decomposition, package
decomposition): `reference.md` in this directory.

**Case law** (deep worked studies):
- Storify → leaf type discovery: `../../examples/storify-leaf-type.md`
- Over-abstraction rejection + cheaper alternatives: `../../examples/overabstraction-cidr.md`
- Incremental global elimination: `../../examples/dependency-rejection.md`
- Duplicated kind-switch → interface dispatch (and the kept-switch rejection): `../../examples/anti-if-dispatch.md`
- Type switch over an owned interface → fill-style method (and the dependency-direction rejection): `../../examples/switch-to-polymorphism.md`
</pattern_index>

<file_and_package_routing>
**`file-length-limit` (>450 lines):**

| File pattern | Action |
|---|---|
| Multiple juicy types | Route to @code-designing — one juicy type per file (juiciness per R1) |
| Single god type (>15 methods) | `reference.md` → god-object decomposition, then @code-designing for the composition |
| Long functions, few types | Storify → extract functions (R3) |

<package_decomposition>
**Package-size zones** — count non-test `.go` files per directory:

```
find <dir> -maxdepth 1 -type f -name '*.go' -not -name '*_test.go' -not -name '*_gen.go' -not -name '*.pb.go' | wc -l
```

≤7 green — fine. 8–12 yellow — design review *before the next file lands*. ≥13 red —
**must decompose**. Either zone: run the 3-step design review in `reference.md` →
"Package decomposition" (it is a *design* review — missing domain types are the
disease, file count the symptom). Invoke @code-designing to validate extracted types.
</package_decomposition>
</file_and_package_routing>

<preparatory_mode>
Fowler's preparatory refactoring — "make the change easy, then make the easy change":
reshape code an approved plan is about to touch, before the first RED, so the feature
lands as add-only. Invoked by @linter-driven-development (Phase 1.5, or Phase 2 RED
friction) or `/go-ldd-prepare`, with a DESIGN PLAN, the touch-point file list, and
findings that already passed the four PREPARE gates (multiply / safe / bounded /
skeptic — the gates live in @linter-driven-development `<phase_1_5_prepare>`; this
mode trusts their verdicts and re-runs none of them). Fully autonomous — no user
confirmation, same as the rest of this skill.

Differences from failure-driven operation:

- **The trigger is the plan, not the linter.** Targets are usually lint-green;
  "still failing → next move" does not apply. Route each finding by its rule (the
  same `<routing_table>` rules own the same fix patterns) and apply.
- **Safety before motion.** Uncovered paths get characterization tests through the
  public API first (@testing); the full suite — not just the touched package — runs
  green after every move, because prep edits existing behavior by definition.
- **Stopping criterion — landing shape, not lint.** Stop when the planned change
  lands as add-only or near-add-only: a new variant = one new file plus one case at
  the dispatch boundary (R11); new behavior = a method on an existing type (R1); new
  code = testable without touching globals (R8). Re-check against the plan after
  each move; shape reached → STOP, even with findings left — those were never
  preparation and belong to Phase 4's advisory report.
- **Commits are segregated.** Prep work lands in its own commit(s), never mixed with
  feature code — the reviewer sees behavior-preserving reshaping and new behavior as
  separate diffs.
</preparatory_mode>

<iteration_loop>
1. Receive trigger (from @linter-driven-development, from the caller acting on accepted
   @pre-commit-review findings, or manual).
2. Route each failure via `<routing_table>`; apply the owning rule's Fix pattern,
   least-invasive move first (sequencing in `reference.md`).
3. Re-run the linter immediately — no user confirmation.
4. Still failing → next move in the sequence. Repeat until green.
5. **Escalation**: complexity failures that keep recurring mean a new type or design
   is needed — invoke @code-designing. Patterns exhausted → report what was tried and
   escalate to the user for architectural guidance.
</iteration_loop>

<testing_integration>
**MANDATORY** after creating new types or extracting functions:
1. List created types: `grep -RnE "^type[[:space:]]+\w+" --include="*.go" .`
2. Missing tests for any of them → STOP and invoke @testing.
3. Coverage: `go test -cover ./...` — leaf types must show 100% (R7).
</testing_integration>

<nolint_prohibition>
**NEVER add `//nolint` to avoid refactoring.** Handle the error, validate at the
boundary, or reduce the complexity. Before finishing, scan all uncommitted files:

```bash
changed_files=$({ git diff --name-only; git diff --cached --name-only; } | sort -u)
[ -n "$changed_files" ] && printf '%s\n' "$changed_files" | xargs grep "//nolint" 2>/dev/null
```

Any hit → remove the directive and fix properly. Genuine false positives belong in
`.golangci.yaml` exclusions — with user approval, never unilaterally.
</nolint_prohibition>

<stopping_criteria>
STOP when ALL are met: linter passes (0 issues); functions <50 LOC, nesting ≤2;
no red-zone packages; code reads like a story; no juicy extraction left (R1 scorecard
says LOW on every remaining candidate). If linter passes AND code is readable → STOP;
over-engineering signs (one-method types, pass-through functions) mean you went too far.
</stopping_criteria>

<output_format>
```
REFACTORING APPLIED

Failures Routed:
1. [linter] → [rule] → [move applied]: [what changed]

Types Created (R1 verdict): [Type] — [why juicy] → @testing invoked
Types Rejected (not juicy): [Type] — [cheaper alternative used]

Metrics: cyclomatic [before]→[after], LOC [before]→[after], nesting [before]→[after]
Files Modified: [file] (+X, -Y)

STATUS: [linter green / still failing: N issues / escalated to @code-designing]
```
</output_format>

<integration>
**Invoked by**: @linter-driven-development (Phase 1.5 / RED friction → `<preparatory_mode>`;
Phase 3, lint failures), or the caller acting
on accepted @pre-commit-review findings (@linter-driven-development Phase 4 accepted
findings, or the user) — @pre-commit-review reports only and never invokes fix skills.
**Invokes**: @code-designing (new types/design needed), @testing (after every extraction
— mandatory), @pre-commit-review (after lint passes). **Loop**: lint fails → @refactoring
→ re-lint → @pre-commit-review → repeat until both pass.
</integration>
