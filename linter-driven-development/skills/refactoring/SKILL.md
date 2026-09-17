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
Fix code that already fails lint or review. This skill is a thin directional view:
every fix pattern lives exactly once in `../../rules/` — this protocol routes each
failure to its owning rule, sequences multi-rule work via `reference.md`, and loops
until green. Operates autonomously — no user confirmation between patterns, and no
user confirmation at the end: every invocation ends with the green tree committed
and the `Stop check` block in the message that ends the turn (`<stopping_criteria>`,
`<output_format>`). "Nothing is committed, ready for your review" is this skill
failing, not finishing — there is no next turn to review in.

Forward counterpart (designing before code exists): @code-designing.
</objective>

<skill_invocation>
**CRITICAL**: When this skill says "Invoke @skill-name", you MUST invoke it with the
**Skill tool** — do not just mention it.

| Notation | Skill Tool Call |
|----------|-----------------|
| @code-designing | `Skill(linter-driven-development:code-designing)` |
| @testing | `Skill(linter-driven-development:testing)` |
| @pre-commit-review | `Skill(linter-driven-development:pre-commit-review)` |
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
| File too long; a directory in the package-size red zone | `../../rules/R5-vertical-slice.md` — mechanics in `<file_and_package_routing>` below |
| Mutable global variable; import-time side effect | `../../rules/R8-no-globals.md` |
| Interface, protocol or abstract class with a single implementation; returning an interface | `../../rules/R6-test-only-interfaces.md` |
| Data race; copied lock; unsynchronized shared state | `../../rules/R10-concurrency-safety.md` |
| Unchecked error, missing error context, magic constant, early-return style, unused symbol, shadowed variable, renames, formatting, import order | Mechanical — fix directly (handle the error, add context when wrapping it, extract the constant, invert & return early, delete or rename). Enum-shaped repeated strings → R1's "Name enum strings" move. |
| A finding no row above describes | Never silenced, never guessed: escalate it to the rule its *message* describes and name the linter it came from. |
</routing_table>

<pattern_index>
Each named refactoring move is owned by one rule's **Fix pattern** section — apply it
from there, never from memory:

| Move | Owner |
|------|-------|
| Extract Function (named after the comment), Early Returns, Honest Rename, Extract Leaf Type | `../../rules/R3-storifying.md` |
| Replace Primitive with Domain Type, Extract Collection Type, Replace Sentinel with comma-ok, Name enum strings, Over-abstraction rejection | `../../rules/R1-primitive-obsession.md` |
| Add validating constructor, Hoist method checks, Delete re-validation, Separate Failure from Absence, Introduce Null Object (optional collaborator) | `../../rules/R2-self-validating-types.md` |
| Demote helper (rung 1), Promote to feature/domain package (rungs 2–3), Split policy from vocabulary | `../../rules/R4-helper-placement.md` |
| Slice out a feature, Rename layer files by role, Split a generic package by owner | `../../rules/R5-vertical-slice.md` |
| Delete the Test Seam, Rewrite test around real collaborators, Delete the double | `../../rules/R6-test-only-interfaces.md` |
| Move test down a rung, Split Success and Error Tables, Replace sleep with synchronization | `../../rules/R7-test-placement.md` |
| Extract Clean Island, Push Global Up One Level, Replace Import-Time Initialization with a Constructor, Pass Cancellation Down | `../../rules/R8-no-globals.md` |
| Inject the Exit Path, Make Concurrent Work Joinable, Extract Synchronized Owner, Replace Sleep with Cancellable Wait, Delete Unearned Guards | `../../rules/R10-concurrency-safety.md` |
| Replace Duplicated Switch with Interface Dispatch, Replace If-Chain with Strategy Map, Introduce Null Object, Split Flag Argument, Keep the Single Exhaustive Switch | `../../rules/R11-conditional-dispatch.md` |
| Copy on the Way In, Copy on the Way Out / Encapsulate Collection, Separate Query from Modifier, Remove Setting Method, Split Variable | `../../rules/R12-mutation-discipline.md` |

**Introduce Null Object, the shape.** The null object is a *named* value of the
collaborator's existing concrete type — a sink composing the standard no-op writer, a
clock that is the real clock — supplied as the constructor's default through an option
or passed by the caller by name. Never a new interface with one no-op implementation
(R6), never a null parameter that means "default" (R2). An option handed null
records the error on the value under construction and the constructor fails with it
(R2's example) — the option never substitutes the default and never stores the
null.

The spelling follows the repository's language: its standard no-op writer, its way
of passing an optional collaborator (an option, a keyword argument, a sentinel
object), and its way of reporting a rejected argument from construction.

**Extract Function prefers the function that exists.** Before writing a helper for a
step — parse, decode, normalize, validate — grep the package for one that already does
it (grep the package for a function named after the step's noun) and prefer
the one with a test. A sibling written beside a tested function is a second owner of
the same rule (R1 Q2), not an extraction; when the existing function has the wrong
shape, change it and its test rather than copy it, and never leave two. A behavioral
difference between the inline code and the existing function — one trims a field, the
other does not — is not a licence for a sibling: it is a bug in one of them (fix it,
with a test) or a parameter of the one function, and the STATUS block names which. Two
parsers of one line format is the finding R1 Q2 exists for.

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
**A file-length limit (the linter's, or ~450 lines when it has none):**

| File pattern | Action |
|---|---|
| Multiple juicy types | Route to @code-designing — one juicy type per file (juiciness per R1) |
| Single god type (>15 methods) | `reference.md` → god-object decomposition, then @code-designing for the composition |
| Long functions, few types | Storify → extract functions (R3) |

<package_decomposition>
**Package-size zones** — count the non-test, non-generated source files in one
directory:

```
find <dir> -maxdepth 1 -type f -name 'detected-language source' -not -name '*<test-file suffix>' | wc -l
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
friction) or `/ldd-prepare`, with a DESIGN PLAN, the touch-point file list, and
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
   escalate to the user for architectural guidance. Frame the escalation in maxim
   vocabulary (`../../maxims.md`) — name *why* the code resists ("every caller asks
   this struct three questions and then decides — the design wants Tell-Don't-Ask"),
   not just which linter stayed red.
6. **Green is the exit condition, not the exit.** Linter green → leave the loop
   through `<stopping_criteria>`: its six steps run in order and each writes its line
   of the `Stop check` block as it finishes. The loop has ended when the block has
   its six lines and sits in the message that ends the turn; a green linter with no
   block is the loop still running.
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
Linter green is where stopping begins, not where it ends. The exit is six actions over
the code this session touched, run in order; each action ends by writing its line of
the `Stop check` block (`<output_format>`). The line is the receipt: an action with no
line has not run, and the line is written when the action finishes, never from memory
at the end.

1. **Gates.** Linter 0 issues; tests green; functions <50 LOC, nesting ≤2; no red-zone
   packages. Line `1 gates`: the four measurements.
2. **Detection re-run.** Re-run the detection commands (each rule's Falsifying
   questions) of every rule routed in this session over the touched files — and for
   R8 over the touched packages, because a package-level variable, an import-time
   initializer or a singleton has no function to sit in: the sibling file of the one just edited is in
   R8's scope, and in no other rule's. The rules routed this session are the outer
   bound: a rule no failure routed here has no re-run and no fix in this session,
   whatever a suppression in the touched code names. Inside that bound, every
   remaining hit is measured by what this session touched, never the file it landed
   in:
   - **Fixed** when the hit sits in a function or type this session changed, or is an
     R8 package-level declaration in a touched package: the second global beside the
     one just removed, the import-time initializer under it, the manufactured root
     context in the function just reshaped, the flag pair in the loop just storified. Route it again;
     a hit here means not done. "Pre-existing" and "unrelated" are not verdicts for
     these — the request that named one global meant the linter, not that line — and
     a suppression directive on a touched function or type is a hit of the rule it
     suppresses (`<nolint_prohibition>`) when that rule was routed this session.
   - **Reported** when it sits anywhere else in a touched file — a function this
     session never opened, a type it only called — or when it is a hit of a rule this
     session never routed, wherever it sits: one `BROADER CONTEXT` line per hit under
     the block (`<output_format>`), `file:line — rule and question — what stands`.
     Reported, not fixed, not silent. Replacing one global read inside a brownfield
     function does not make that function's eight-linter `lint-suppression` this session's
     work: the complexity rules it names were never routed by a globals request, so
     the directive is a line in the report, never a storifying detour. The reverse
     bound holds too: a hit in code this session wrote or moved is never a BROADER
     CONTEXT line — the sibling parser this session extracted beside the tested one
     (R1 Q2) is fixed, and "pre-existing" is not a word for it.
   Line `2 re-run`: every rule routed this session by id and, per rule, `0 hits`, the
   anchor still standing and where it was routed again, or `n reported` for the hits
   on BROADER CONTEXT lines.
3. **The noun check.** For each concept the touched code handles, ask once: does it
   have a named box? A slice walked with flags is a collection type *over that slice*
   — R1's Extract Collection Type: `type Nodes []Node`, and the loop becomes named
   query methods on it — not an accumulator that stands beside the loop (that is the
   flags renamed); an optional collaborator that may be absent is a Null Object
   default, never an optional field that may be absent, and an option handed null records the error for
   the constructor to return rather than storing it or substituting the default; a
   value parsed in two places has one constructor; a repeated predicate is a method.
   Score each candidate with R1's scorecard: ≥4 → apply the
   move; 2–3 → apply it or record the judgment call in the STATUS block; 0–1 → leave
   it. A candidate is never skipped because the linter is already quiet. Line
   `3 nouns`: each candidate with its score and verdict — `none scored ≥2` when
   nothing qualified, never a blank.
4. **The comment critic.** Spawn one `linter-driven-development:comment-critic` (Agent tool, foreground) over
   the touched files with the payload @pre-commit-review step 3b names, and state the
   scope in the spawn prompt as *every comment in each touched file*, not the changed
   lines — the `Sink is where events are written.` doc comment beside the code just
   reshaped restates its name whether or not this session wrote it. Apply its
   TRIM / REWRITE / DELETE verdicts — a comment edit is small — and route its
   `DELETE → route R3` verdicts back to step 3. Line `4 critic`: the verdict counts
   applied and routed.
5. **STOP**, and read the over-engineering signs as a check on step 3, never as a
   reason to skip it: a one-method type that merely unwraps, a function that only
   calls another, more layers than concepts — undo that move. Line `5 STOP`: none of
   the signs, or the move undone.
6. **Commit.** Tests and lint green and the tree dirty → `git commit` with the STATUS
   block's summary as the message — one commit per green step when the caller asked
   for deployable steps, and for R8 a step is one island and its caller (Extract Clean
   Island, then Push the Global Up One Level, one level per commit), never every
   caller threaded at once — so the green tree outlives the session. Inside the
   workflow, Phase 5 commits the slice it ships; a standalone invocation commits
   here, now, before the report. A report that ends with "let me know if you'd like
   me to commit" or "your call" is the failure this step exists to prevent: there is
   no next turn. Line `6 commit`: the hash and message, `Phase 5 commits the slice`,
   or `tree clean, nothing to commit`.

The six lines are the block, and the block goes where the user reads: the message
that ends the turn, whichever path invoked this skill — a standalone invocation's
report, the workflow's Phase 5 ship summary, quickfix's ship summary. A caller that
summarises this skill's work carries the block verbatim above its own summary, and
the BROADER CONTEXT lines under it travel with the block: what step 2 reported instead
of fixing is the caller's to hear, not this session's to bury. Prose
that narrates the steps ("re-ran detection, spawned the critic, committed") in place
of the six lines is the block missing, and a missing block means the refactoring did
not finish.
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
2 re-run     [R3, R1, R8]: [0 hits / file.<ext>:NN still — routed again]
3 nouns      [Region (score 5) → Replace Primitive with Domain Type applied; Tags (score 2) → recorded]
4 critic     [n] verdicts applied · [n] DELETE → routed R3
5 STOP       [none of the over-engineering signs / undone: <move>]
6 commit     [abc1234 "<message>" / Phase 5 commits the slice / tree clean, nothing to commit]

BROADER CONTEXT
  [file.<ext>:NN — R3 Q1 — lint-suppression on an eight-linter function this session never opened / none]

STATUS: [linter green / still failing: N issues / escalated to @code-designing]
```
Every line of `Stop check` renders, in this order, with a result — never a bare
checkmark; a missing line means the step did not run and the STATUS is not final.
Each line opens with its step number and keyword exactly as shown — `1 gates`,
`2 re-run`, `3 nouns`, `4 critic`, `5 STOP`, `6 commit` — so the six receipts can be
found without reading the prose, and the result follows on the same line. Under the
block, `BROADER CONTEXT` lists every hit step 2 reported rather than fixed, one line
each with its `file:line`, rule and question, or `none`. The block and its BROADER
CONTEXT lines are copied verbatim into whatever message ends the turn
(`<stopping_criteria>`).
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
