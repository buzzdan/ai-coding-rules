---
name: refactoring
description: |
  BACKWARD view over rules/ — routes linter and review failures to the rule whose Fix pattern owns the repair.
  Use when linter fails with complexity issues (cyclomatic, cognitive, maintainability) or when code feels hard to read/maintain.
  Also the skill for removing a `//nolint` directive or a package-level global (R8): "drop the suppression", "remove the global", "make the linter pass without suppressions" route here, one green step per commit.
  Also runs PREPARATORY mode: reshape code an approved plan touches, before the first RED, so the feature lands add-only.
  Applies storifying, type extraction, function extraction, conditional-dispatch, and mutation-discipline patterns via rules/R1-R8 and R10-R12.
allowed-tools:
  - Skill(go-linter-driven-development:code-designing)
  - Skill(go-linter-driven-development:testing)
  - Skill(go-linter-driven-development:pre-commit-review)
---

<objective>
Fix code that already fails lint or review. A thin directional view: every fix pattern
lives once in `../../rules/`; this protocol routes each failure to its owning rule and
loops until green. Autonomous — no user confirmation between patterns or at the end:
every invocation ends with the green tree committed and the `Stop check` block in the
message that ends the turn; "ready for your review" is this skill failing, not
finishing. Each step's long form is in `reference.md` here, read by `sed` range inside
a Bash call the step already makes — the loop's first lint run, the Gates run of the
exit — never the file whole and never a call of its own. Forward counterpart:
@code-designing.
</objective>

<skill_invocation>
"Invoke @skill-name" means call the **Skill tool** — `Skill(go-linter-driven-development:code-designing)`,
`Skill(go-linter-driven-development:testing)`, `Skill(go-linter-driven-development:pre-commit-review)` — never just mention
it. This skill runs in the thread that invoked it: its moves are never delegated to a
general-purpose or any other subagent; the one agent it spawns is the comment critic
of step 4 below.
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
| revive `file-length-limit`; package-size hook failures (`hooks/check-package-sizes.sh`) | `../../rules/R5-vertical-slice.md` — mechanics in `<file_and_package_routing>`, `sed -n '/^## File and package routing/,/^## Preparatory mode/p'` over this skill's `reference.md` |
| `gochecknoglobals` / `gochecknoinits` | `../../rules/R8-no-globals.md` |
| `ireturn` / interface lint on single-impl interfaces | `../../rules/R6-test-only-interfaces.md` |
| `go test -race` failures; `govet` `copylocks` | `../../rules/R10-concurrency-safety.md` |
| `wrapcheck`, `errcheck`, `goconst`, revive `early-return`, renames | Mechanical — fix directly (`fmt.Errorf("context: %w", err)`, handle the error, extract constant, invert & return early). Enum-shaped `goconst` strings → R1's "Name enum strings" move. |
</routing_table>

<pattern_index>
Each named move is owned by one rule's **Fix pattern** section — apply it from there,
never from memory. Which rule owns which move, the shape of Introduce Null Object, and
why Extract Function prefers the tested function that already exists over a sibling —
print it in the same Bash call as the loop's opening linter run (step 2, before any
move), never as a call of its own: `sed -n '/^## Pattern index/,/^## File and package routing/p' <this skill dir>/reference.md`.
Add to that call, when a file-length or package-size failure is routed,
`sed -n '/^## File and package routing/,/^## Preparatory mode/p; /^### Package decomposition/,$p'`
(`<file_and_package_routing>`, `<package_decomposition>` and the procedure), and when
several rules are routed on one function,
`sed -n '/^## Multi-rule procedures/,$p'` (sequencing, god-object and package decomposition).
</pattern_index>

<preparatory_mode>
Fowler's preparatory refactoring — reshape code an approved plan is about to touch,
before the first RED, so the feature lands add-only. Invoked by @linter-driven-development
(Phase 1.5, or RED friction) or `/go-ldd-prepare` with a DESIGN PLAN, the
touch-point files and findings that already passed the four PREPARE gates; this mode
re-runs none of them. The trigger is the plan, not the linter; characterization tests
come before motion; the stop is the landing shape (add-only), not lint; prep lands in
its own commits. In full, printed in the loop's opening lint call (step 2) when this
mode is the one invoked, before any move: `sed -n '/^## Preparatory mode/,/^## Stopping criteria/p' <this skill dir>/reference.md`.
</preparatory_mode>

<iteration_loop>
1. Receive the trigger (from @linter-driven-development, from the caller acting on
   accepted @pre-commit-review findings, or manual).
2. Run the linter once over the scope, before any move, and print in that same Bash
   call the ranges `<pattern_index>` names: the pattern index always; file and package
   routing with its procedure when such a failure is routed; preparatory mode when
   that is the mode. This is the one read of `reference.md` the loop makes.
3. Route each failure via `<routing_table>`; apply the owning rule's Fix pattern,
   least-invasive move first (sequencing: "Multi-rule procedures", `<pattern_index>`).
4. Re-run the linter immediately — no user confirmation.
5. Still failing → next move in the sequence. Repeat until green.
6. **Escalation**: complexity failures that keep recurring mean a new type or design
   is needed — invoke @code-designing. Patterns exhausted → report what was tried and
   escalate to the user, framed in maxim vocabulary (`../../maxims.md`): name *why*
   the code resists, not just which linter stayed red.
7. **Green is the exit condition, not the exit.** Linter green → leave through
   `<stopping_criteria>`: six steps in order, each writing its line of the `Stop check`
   block as it finishes. A green linter with no block is the loop still running.
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

A `//nolint` that was already in a touched file is the same hit when it names a linter
of a rule routed this session and sits on a function or type this session changed, or
on a package-level declaration in a touched package (`gochecknoglobals` → R8,
`gochecknoinits` → R8 in a globals request): it suppresses the rule it names, so route
it as a finding of that rule and delete it with the fix. "Pre-existing" and "unrelated"
are not verdicts for those — a request to make the linter pass without suppressions is
met when the touched functions and the touched packages' declarations carry none of
the routed rules' directives, not when the one directive the request named is gone and
its neighbours keep their `// TODO`. A directive elsewhere in a touched file, or one
naming a linter of a rule this session never routed — `gocyclo,gocognit` → R3 on the
function whose one global read was just replaced — is a BROADER CONTEXT line under the
`Stop check` block: reported with its rule, not fixed in this session, not silent.
</nolint_prohibition>

<stopping_criteria>
Linter green is where stopping begins. The exit is six actions over the code this
session touched, in order; each ends by writing its line of the `Stop check` block
(`<output_format>`) — the line is the receipt, written when the action finishes, never
from memory at the end. The Gates run (step 1) prints the six steps in full in the same
Bash call as the lint and tests, never a call of their own:
`sed -n '/^## Stopping criteria, in full/,/^## Integration/p' <this skill dir>/reference.md`;
they govern steps 2 to 6.

1. **Gates.** Linter 0 issues; tests green; functions <50 LOC, nesting ≤2; no red-zone
   packages. Line `1 gates`: the four measurements.
2. **Detection re-run.** Re-run the detection commands of every rule routed this
   session over the touched files (R8: the touched packages). A hit in a function or
   type this session changed, or an R8 declaration in a touched package, is **fixed** —
   routed again, "pre-existing" is no verdict; a hit anywhere else in a touched file, or
   of a rule never routed, is **reported** as one `BROADER CONTEXT` line (`file:line —
   rule and question — what stands`). Line `2 re-run`: per routed rule, `0 hits`, the
   anchor routed again, or `n reported`.
3. **The noun check.** For each concept the touched code handles: does it have a named
   box? A slice walked with flags is a collection type over it (R1); an optional
   collaborator is a Null Object default; a value parsed twice has one constructor; a
   repeated predicate is a method. Score each with R1's scorecard: ≥4 apply; 2–3 apply
   or record the judgment call; 0–1 leave. Line `3 nouns`: each candidate with score
   and verdict — `none scored ≥2` when nothing qualified, never a blank.
4. **The comment critic.** Spawn one `go-linter-driven-development:comment-critic` (Agent tool,
   foreground) over the touched files, its spawn prompt carrying, as absolute paths,
   `../../rules/R9-repo-brain.md` with `sed -n '/^### Comment policy/,/^### Edge conventions/p'`,
   `../documentation/reference.md` with `sed -n '/^## Comment Value Toolbox/,/^## Frontmatter Templates/p'`,
   and `../../examples/private-comment-noise.md`, and the scope stated as *every
   comment in each touched file*. Apply its TRIM / REWRITE / DELETE verdicts; route
   `DELETE → route R3` back to step 3. Line `4 critic`: verdicts applied and routed.
5. **STOP**, reading the over-engineering signs as a check on step 3: a one-method type
   that merely unwraps, a function that only calls another, more layers than concepts
   — undo that move. Line `5 STOP`: none of the signs, or the move undone.
6. **Commit.** Tests and lint green and the tree dirty → `git commit` with the STATUS
   summary — one commit per green step when deployable steps were asked for (R8: one
   island and its caller per commit). Inside the workflow, Phase 5 commits the slice; a
   standalone invocation commits here, before the report. Line `6 commit`: the hash and
   message, `Phase 5 commits the slice`, or `tree clean, nothing to commit`.

The six lines are the block, and the block goes in the message that ends the turn,
whichever path invoked this skill; a caller that summarises this work carries it and
its BROADER CONTEXT lines verbatim. Prose narrating the steps in place of the six lines
is the block missing, and a missing block means the refactoring did not finish.
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

Stop check:
1 gates      lint 0 · tests green · max LOC [n] · max nesting [n]
2 re-run     [R3, R1, R8]: [0 hits / file.go:NN still — routed again]
3 nouns      [Region (score 5) → Replace Primitive with Domain Type applied; Tags (score 2) → recorded]
4 critic     [n] verdicts applied · [n] DELETE → routed R3
5 STOP       [none of the over-engineering signs / undone: <move>]
6 commit     [abc1234 "<message>" / Phase 5 commits the slice / tree clean, nothing to commit]

BROADER CONTEXT
  [file.go:NN — R3 Q1 — //nolint on an eight-linter function this session never opened / none]

STATUS: [linter green / still failing: N issues / escalated to @code-designing]
```
Every `Stop check` line renders, in this order, opening with its number and keyword
exactly as shown — `1 gates` … `6 commit` — with its result on the same line; a missing
line means the step did not run and the STATUS is not final. `BROADER CONTEXT` lists
every hit step 2 reported rather than fixed, or `none`. Who invokes this skill and what
it invokes: `sed -n '/^## Integration/,/^## Multi-rule procedures/p' <this skill dir>/reference.md`.
</output_format>
