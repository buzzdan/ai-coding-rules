---
name: refactoring
description: |
  BACKWARD view over rules/ — routes linter and review failures to the rule whose Fix pattern owns the repair.
  Use when linter fails with complexity issues (cyclomatic, cognitive, maintainability) or when code feels hard to read/maintain.
  Also the skill for removing a `lint-suppression` directive or a package-level global (R8): "drop the suppression", "remove the global", "make the linter pass without suppressions" route here, one green step per commit.
  Also runs PREPARATORY mode: reshape code an approved plan touches, before the first RED, so the feature lands add-only.
  Applies storifying, type extraction, function extraction, conditional-dispatch, and mutation-discipline patterns via rules/R1-R8 and R10-R12.
allowed-tools:
  - Skill(linter-driven-development:code-designing)
  - Skill(linter-driven-development:testing)
  - Skill(linter-driven-development:pre-commit-review)
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
"Invoke @skill-name" means call the **Skill tool** — `Skill(linter-driven-development:code-designing)`,
`Skill(linter-driven-development:testing)`, `Skill(linter-driven-development:pre-commit-review)` — never just mention
it. This skill runs in the thread that invoked it and applies no move itself and
edits no source file: the moves, the comment critic's verdicts and R9's doc fixes all
go to `linter-driven-development:move-implementer` slices (`<slices>` below), spawned by that name
with the Agent tool, foreground; the only other agent it spawns is the comment critic
of step 4, and never a general-purpose one. The parent routes, writes the slices table,
runs the slicing script, reads receipts and lists the workers' commits.
</skill_invocation>

<routing_table>
Normative linter→rule routing, keyed by what a finding is *about*. The rows name
the finding families most linters report under some name; route the repository's
own linter by the family its message describes, whatever the check is called. (The
lint-fixer agent embeds a compact copy of this table in `../../agents/lint-fixer.md`
— keep them consistent.)

| Linter failure | Route |
|---|---|
| Cyclomatic or cognitive complexity over the limit | `../../rules/R3-storifying.md` |
| Function too long | `../../rules/R3-storifying.md` |
| Nesting too deep | `../../rules/R3-storifying.md` |
| Maintainability index too low | `../../rules/R3-storifying.md` + `../../rules/R1-primitive-obsession.md` |
| Duplicated code | `../../rules/R1-primitive-obsession.md` (extract shared type/logic); duplicated blocks that switch on the same kind/type discriminator → `../../rules/R11-conditional-dispatch.md` |
| Non-exhaustive switch or match (missing enum cases) | `../../rules/R11-conditional-dispatch.md` — handle the case at the single dispatch site; a second switch appearing is the R11 violation itself |
| File too long; a directory in the package-size red zone | `../../rules/R5-vertical-slice.md` — mechanics in `<file_and_package_routing>`, `sed -n '/^## File and package routing/,/^## Preparatory mode/p'` over this skill's `reference.md` |
| Mutable global variable; import-time side effect | `../../rules/R8-no-globals.md` |
| Interface, protocol or abstract class with a single implementation; returning an interface | `../../rules/R6-test-only-interfaces.md` |
| Data race; copied lock; unsynchronized shared state | `../../rules/R10-concurrency-safety.md` |
| Unchecked error, missing error context, magic constant, early-return style, unused symbol, shadowed variable, renames, formatting, import order | Mechanical — fix directly (handle the error, add context when wrapping it, extract the constant, invert & return early, delete or rename). Enum-shaped repeated strings → R1's "Name enum strings" move. |
| A finding no row above describes | Never silenced, never guessed: escalate it to the rule its *message* describes and name the linter it came from. |
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

<slices>
A slice is the moves that share a file, in sequence, over those files; the script
below composes it, never the parent. Write `slices.tsv` under a fresh `mktemp -d`
(`<dir>`): one line per routed finding or lint escalation, four tab-separated fields —
`R<n>`, the move as the rule's Fix pattern spells it (a combined name is two lines),
the files (relative paths, space-separated), the finding's `file:line`. Run
`S=<this skill dir>/../../scripts; bash "$S/ldd-slices.sh" <dir>/slices.tsv`: it groups
the lines that share a file, orders a slice's moves as the multi-rule procedures
sequence them, assigns waves so that no two slices of one wave touch the same package,
and prints one block per slice (`MOVE n:` lines, `FILES:`, `PKGS:`, `RULE:`); a move
name that is not the rule's spelling is refused with the valid keys. Before the first
wave: the tree is clean — `git status --porcelain` prints nothing; when it does, commit
the tree first (the step's own message), because a worker restores its files to `BASE:`
on a deferral and commits them whole when green, and uncommitted work in those files
would be lost or swept into a move's commit. Then run `TEST:` once and record the names
of the tests that fail as `BASE-RED:` (or `none`). Then, wave by wave: spawn every slice of the wave **in one message** — one
`linter-driven-development:move-implementer` per slice, Agent tool, foreground — with the slice's
block and these lines appended, and no pasted rule text or source:
`BASE: <git rev-parse HEAD>` · `BASE-RED: <names, or none>` · `TEST: <the project's test command>` · `LINT: <the line bash "$S/ldd-attempt.sh" --lint-delta <BASE> <the slice's FILES> prints>` · `BUILD: <the project's build command, or none>` · `WRAPPER: <absolute path of $S/ldd-attempt.sh>` · `REPORT: <mktemp -d>`.
Read the receipts, not the tree, and append one line per slice and status to
`<dir>/slices.log` as they arrive, so a compacted parent re-dispatches nothing. Before
the next wave, spot-check every `COMMIT:` with `git show --name-only <sha>`: a commit
that touches a file outside its slice's `FILES:` — a new file inside one of its `PKGS:`
excepted — is a `Stop check` line, never silently kept. `DEFERRED-NEEDS: <files>` → one re-spawn in the next wave, the files
appended to the slice's line in `slices.tsv` and the script run again; a second
`DEFERRED-NEEDS` is final. `DEFERRED` and `NEEDS_CONTEXT` are lines of the `Stop check`
block and the ship summary, never a reason for the parent to apply the move by hand.
The comment critic's verdicts (step 4) and R9's doc fixes are slices too: save the
verdict text to `<dir>/verdicts-<n>.txt` and add the line `R9` · `Apply comment
verdicts` · the files · that path, which the script orders last. The long form —
the table, the script, waves, BASE-RED, the wrapper, the re-spawn rule, the
spot-check, the ledger, the receipt statuses — rides in the loop's opening Bash call
with the pattern index (`sed -n '/^## Slices and receipts/,/^## File and package routing/p'`).
</slices>

<preparatory_mode>
Fowler's preparatory refactoring — reshape code an approved plan is about to touch,
before the first RED, so the feature lands add-only. Invoked by @linter-driven-development
(Phase 1.5, or RED friction) or `/ldd-prepare` with a DESIGN PLAN, the
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
3. Route each failure via `<routing_table>` to the owning rule's Fix-pattern move,
   least-invasive move first (sequencing: "Multi-rule procedures", `<pattern_index>`);
   write the slices table, run the slicing script, spawn the waves (`<slices>`).
4. Read the receipts wave by wave — green moves are committed — and after the last
   wave re-run the linter once over the scope, immediately, no user confirmation.
5. Still failing → the next move in the sequence: a new table with the next move per
   anchor, the script again, new workers. Repeat until green. A move deferred twice
   (`DEFERRED-NEEDS` re-spawned once and deferred again, or `DEFERRED`) is not routed
   again; it is a line in the block.
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
1. List created types: the type, class or struct declarations among the diff's added
   lines (`git diff -U0 -- 'detected-language source'`, added lines that declare a new type).
2. Missing tests for any of them → STOP and invoke @testing.
3. Coverage: the repository's test command with its coverage flag — leaf types must
   show 100% (R7).
</testing_integration>

<nolint_prohibition>
**NEVER add a lint-suppression directive to avoid refactoring.** Handle the error, validate
at the boundary, or reduce the complexity. Before finishing, scan all uncommitted
files for the language's suppression directive — `# noqa`, `# type: ignore`,
`eslint-disable`, `#[allow(...)]`, `@SuppressWarnings`, or whatever the repository's
linter documents:

```bash
changed_files=$({ git diff --name-only; git diff --cached --name-only; } | sort -u)
[ -n "$changed_files" ] && printf '%s\n' "$changed_files" | xargs grep -nE '<the suppression directive>' 2>/dev/null
```

Any hit → remove the directive and fix properly. Genuine false positives belong in
the linter's configuration file — with user approval, never unilaterally.

A lint-suppression directive that was already in a touched file is the same hit when it
names a linter of a rule routed this session and sits on a function or type this
session changed, or on a package-level declaration in a touched package (a
globals check → R8, an import-time-initializer check → R8 in a globals request): it
suppresses the rule it names, so route it as a finding of that rule and delete it with
the fix. "Pre-existing" and "unrelated" are not verdicts for those — a request to make
the linter pass without suppressions is met when the touched functions and the
touched packages' declarations carry none of the routed rules' directives, not when
the one directive the request named is gone and its neighbours keep their `TODO`. A
directive elsewhere in a touched file, or one naming a linter of a rule this session
never routed — a complexity suppression → R3 on the function whose one global read
was just replaced — is a BROADER CONTEXT line under the `Stop check` block: reported
with its rule, not fixed in this session, not silent.
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
2. **Detection re-run.** One Bash call: `S=<this skill dir>/../../scripts; out=$(bash "$S/ldd-scope.sh" <the touched files>); echo "$out"; case "$out" in *'nothing to review') ;; *) bash "$S/ldd-detect.sh" "${out##* }" ;; esac` — the counts table over the touched files (R8: every file of the touched packages). A hit of a rule routed this session, in a function or type this session changed, or an R8 declaration in a touched package, is **fixed** — a new slice, routed again, "pre-existing" is no verdict; a hit anywhere else in a touched file, or of a rule never routed, is **reported** as one `BROADER CONTEXT` line (`file:line — rule and question — what stands`). Line `2 re-run`: per routed rule, `0 hits`, the anchor routed again, or `n reported`.
3. **The noun check.** For each concept the touched code handles: does it have a named
   box? A slice walked with flags is a collection type over it (R1); an optional
   collaborator is a Null Object default; a value parsed twice has one constructor; a
   repeated predicate is a method. Score each with R1's scorecard: ≥4 apply; 2–3 apply
   or record the judgment call; 0–1 leave. Line `3 nouns`: each candidate with score
   and verdict — `none scored ≥2` when nothing qualified, never a blank.
4. **The comment critic.** Inside the workflow, when Phase 4's review follows this
   session, skip this step — the review's critic covers the touched files once — and
   write `4 critic: Phase 4`. Standalone, or when no review follows: spawn one
   `linter-driven-development:comment-critic` (Agent tool,
   foreground) over the touched files, its spawn prompt carrying, as absolute paths,
   `../../rules/R9-repo-brain.md` with `sed -n '/^### Comment policy/,/^### Edge conventions/p'`,
   `../documentation/reference.md` with `sed -n '/^## Comment Value Toolbox/,/^## Frontmatter Templates/p'`,
   and `../../examples/private-comment-noise.md`, and the scope stated as *every
   comment in each touched file*. Its TRIM / REWRITE / DELETE verdicts go to one
   `Apply comment verdicts` slice (`<slices>`), never applied by this thread; route
   `DELETE → route R3` back to step 3. Line `4 critic`: verdicts to the slice and routed.
5. **STOP**, reading the over-engineering signs as a check on step 3: a one-method type
   that merely unwraps, a function that only calls another, more layers than concepts
   — undo that move. Line `5 STOP`: none of the signs, or the move undone.
6. **Commits.** The workers committed each green move; list every hash. The parent's
   tree is clean: it edited nothing. Inside the workflow, Phase 5 commits nothing for
   the slices and lists these hashes. Line `6 commit`: one `<sha> <subject>` per green
   move, or `no green move`.

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
0 slices     [k] slices in [w] waves — [n] GREEN · [n] PARTIAL-GREEN · [n] DEFERRED · [n] NEEDS_CONTEXT · [n] re-spawned · [n] commits spot-checked
1 gates      lint 0 · tests green · max LOC [n] · max nesting [n]
2 re-run     [R3, R1, R8]: [0 hits / file.<ext>:NN still — routed again]
3 nouns      [Region (score 5) → Replace Primitive with Domain Type applied; Tags (score 2) → recorded]
4 critic     [n] verdicts to a slice · [n] DELETE → routed R3
5 STOP       [none of the over-engineering signs / undone: <move>]
6 commit     [abc1234 "Extract Leaf Type: …" · def5678 "…" / no green move]

BROADER CONTEXT
  [file.<ext>:NN — R3 Q1 — lint-suppression on an eight-linter function this session never opened / none]

STATUS: [linter green / still failing: N issues / escalated to @code-designing]
```
Every `Stop check` line renders, in this order, opening with its number and keyword
exactly as shown — `0 slices` … `6 commit` — with its result on the same line; a missing
line means the step did not run and the STATUS is not final. `BROADER CONTEXT` lists
every hit step 2 reported rather than fixed, or `none`. Who invokes this skill and what
it invokes: `sed -n '/^## Integration/,/^## Multi-rule procedures/p' <this skill dir>/reference.md`.
</output_format>
