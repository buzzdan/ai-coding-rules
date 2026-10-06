---
name: refactoring
description: |
  BACKWARD view over rules/ — routes linter and review failures to the rule whose Fix pattern owns the repair.
  Use when linter fails with complexity issues (cyclomatic, cognitive, maintainability) or when code feels hard to read/maintain.
  Also the skill for removing a `// eslint-disable-next-line` directive or a package-level global (R8): "drop the suppression", "remove the global", "make the linter pass without suppressions" route here, one green step per commit.
  Also runs PREPARATORY mode: reshape code an approved plan touches, before the first RED, so the feature lands add-only.
  Applies storifying, type extraction, function extraction, conditional-dispatch, and mutation-discipline patterns via rules/R1-R8 and R10-R12.
allowed-tools:
  - Skill(ts-react-linter-driven-development:code-designing)
  - Skill(ts-react-linter-driven-development:testing)
  - Skill(ts-react-linter-driven-development:pre-commit-review)
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
| @code-designing | `Skill(ts-react-linter-driven-development:code-designing)` |
| @testing | `Skill(ts-react-linter-driven-development:testing)` |
| @pre-commit-review | `Skill(ts-react-linter-driven-development:pre-commit-review)` |
</skill_invocation>

<routing_table>
Normative linter→rule routing, keyed by ESLint rule ids. (The lint-fixer agent
embeds a compact copy of this table in `../../agents/lint-fixer.md` — keep them
consistent.) ESLint has no duplicate-code (beyond `sonarjs/no-identical-functions`),
single-implementer or exhaustiveness rule unless configured, and there is no race
detector: those rows are review findings the hunters own alone.

| Linter failure | Route |
|---|---|
| `sonarjs/cognitive-complexity` / `sonarjs/cyclomatic-complexity` | `../../rules/R3-storifying.md` |
| `sonarjs/max-lines-per-function` / `sonarjs/nested-control-flow` / `sonarjs/no-nested-conditional` / `sonarjs/no-nested-functions` / `sonarjs/expression-complexity` / `sonarjs/elseif-without-else` | `../../rules/R3-storifying.md` |
| `react/no-unstable-nested-components` | `../../rules/R3-storifying.md` — extract the component; place it per `../../rules/R4-helper-placement.md` |
| `max-params` | `../../rules/R1-primitive-obsession.md` (Introduce Parameter Object — a `readonly` props/options type, scored) |
| `sonarjs/no-duplicate-string` on an enum-shaped literal; `no-magic-numbers` on a domain value; `sonarjs/max-union-size` | `../../rules/R1-primitive-obsession.md` (Name enum strings, or a named type) |
| `sonarjs/no-identical-functions`; duplicated code (review-only) | `../../rules/R1-primitive-obsession.md` (extract shared type/logic); duplicated `switch`/if-chains on the same kind/type discriminator → `../../rules/R11-conditional-dispatch.md` |
| `sonarjs/max-lines` (600) | `../../rules/R5-vertical-slice.md` — mechanics in `<file_and_package_routing>` below |
| `react/no-multi-comp` | `../../rules/R5-vertical-slice.md` — one component per file; the page folder decides where the second goes |
| `@typescript-eslint/no-explicit-any` / `@typescript-eslint/no-unsafe-*` / `@typescript-eslint/no-non-null-assertion` / `@typescript-eslint/no-unnecessary-condition` at a boundary | `../../rules/R2-self-validating-types.md` (parse at the boundary — a guard, not an assertion) |
| `@typescript-eslint/switch-exhaustiveness-check` (when configured; review-only otherwise) / `sonarjs/no-nested-switch` / `sonarjs/max-switch-cases` / `sonarjs/no-small-switch` | `../../rules/R11-conditional-dispatch.md` — handle the case at the single dispatch site and close it with `default: return assertNever(x)`; a second `switch` appearing is the R11 violation itself |
| Three or more boolean props on one component; an `isLoading`/`isError`/`isEmpty` triplet (review-only) | `../../rules/R11-conditional-dispatch.md` — Split Flag Argument when the branches share little; a status union when they are mutually exclusive |
| `react-hooks/exhaustive-deps` / `react-hooks/set-state-in-effect` / `@typescript-eslint/no-floating-promises` / `@typescript-eslint/no-misused-promises` / `promise/catch-or-return` | `../../rules/R10-concurrency-safety.md` (`no-floating-promises` is mechanical when the fix is `await`, or `void` only at an entry point for genuinely fire-and-forget work; otherwise R10) |
| `react/no-array-index-key` when the item has no id field (review the type) | `../../rules/R1-primitive-obsession.md` — the list element has no identity, which is a missing type, not a key problem |
| `jsx-a11y/click-events-have-key-events` / `jsx-a11y/no-static-element-interactions` / `jsx-a11y/interactive-supports-focus` when the honest fix is `role` + `tabIndex` + `onKeyDown` on a non-interactive element | Escalate — a design question for the component (a `button`, a `Link`), not a markup fix |
| `import/no-mutable-exports`; `no-restricted-syntax` on `import.meta.env` outside the config module (when configured); import-time side effects (review-only) | `../../rules/R8-no-globals.md` |
| `no-param-reassign` / `sonarjs/prefer-read-only-props` / `react/no-direct-mutation-state`; an in-place `.sort()`/`.splice()` on query data (review-only) | `../../rules/R12-mutation-discipline.md` |
| A `vi.mock` of an internal module; an interface with one implementation (review-only) | `../../rules/R6-test-only-interfaces.md` |
| `unused-imports/no-unused-imports`, `unused-imports/no-unused-vars`, `@typescript-eslint/no-unused-vars`, `simple-import-sort/*`, `import/order`, `import/no-duplicates`, `@typescript-eslint/consistent-type-imports`, `curly`, `arrow-body-style`, `no-console`, `prefer-const`, `eqeqeq`, `no-plusplus`, `react/jsx-*` ordering and `react/jsx-no-leaked-render`, `react/no-array-index-key` when the item has an id (`key={item.id}`), `react/forbid-dom-props` / `react/forbid-component-props` on an inline `style` (the SCSS module class), the `jsx-a11y` families `click-events-have-key-events`, `no-static-element-interactions`, `interactive-supports-focus`, `label-has-associated-control`, `aria-props`, `aria-proptypes`, `role-has-required-aria-props`, `alt-text`, `img-redundant-alt` when the fix is one attribute or a `button` for a `div onClick`, Prettier | Mechanical — fix directly (import the type, add the `alt`/`htmlFor`/role, wrap the `&&` render in a boolean, delete the unused symbol, sort the imports). Enum-shaped `sonarjs/no-duplicate-string` literals and `=== 'READY'` comparisons → R1's "Name enum strings" move. An `@ts-expect-error` on `return undefined` is R1 Q4 — never a suppression. |
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
(R6), never a undefined parameter that means "default" (R2). An option handed undefined
records the error on the value under construction and the constructor fails with it
(R2's example) — the option never substitutes the default and never stores the
undefined.

**In TypeScript:** `const NULL_SINK: Sink = { write() {} }` bound once as a module
constant (an object literal typed as the collaborator — never a class with one no-op
method, R6), and a clock that is `const SYSTEM_CLOCK: Clock = { now: () => new Date() }`
the same way; the parameter is typed `Sink`, never `Sink | undefined`, and the default
is a destructuring default — `constructor({ sink = NULL_SINK }: ReporterOptions)`,
`function useReporter({ sink = NULL_SINK }: Readonly<ReporterOptions>)` — so the
stored field is `Sink`, no method guards it, and the caller never has a reason to pass
`undefined`. In React an optional callback prop (`onOpenEvents?`) is legitimate when
the component means something without it; when every render path guards it, the prop
is required, or takes the Null Object in the same destructuring default.

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
**`sonarjs/max-lines` (600; or a module over ~450 lines where the repository sets no limit — count):**

| File pattern | Action |
|---|---|
| Multiple juicy types | Route to @code-designing — one juicy type per module (juiciness per R1) |
| Single god component or class (>15 handlers/methods) | `reference.md` → god-object decomposition, then @code-designing for the composition |
| Long functions, few types | Storify → extract functions and hooks (R3) |
| Several components in one file (`react/no-multi-comp`) | One component per file; the page folder decides where the second lands (R4, R5) |

<package_decomposition>
**Package-size zones** — count non-test `.ts`/`.tsx` modules per directory:

```
find <dir> -maxdepth 1 -type f \( -name '*.ts' -o -name '*.tsx' \) -not -name '*.test.*' -not -name '*.d.ts' -not -name 'index.ts' | wc -l
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
friction) or `/tsr-ldd-prepare`, with a DESIGN PLAN, the touch-point file list, and
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
**MANDATORY** after creating new types or extracting functions, hooks or components:
1. List created types: `grep -rnE "^export (interface|type|class)[[:space:]]+\w+" --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`
2. Missing tests for any of them → STOP and invoke @testing. Before a move,
   characterization tests through the public API (`renderWithProviders` + MSW,
   never a `vi.mock` of the module being moved); `npx vitest run <dir>` after each step.
3. Coverage: `npx vitest run --coverage` (or the repository's coverage command) —
   leaf types must show 100% (R7).
</testing_integration>

<nolint_prohibition>
**NEVER add `// eslint-disable-next-line`, `@ts-expect-error` or `@ts-ignore` to
avoid refactoring.** Handle the error, parse at the boundary, or reduce the
complexity. Before finishing, scan all uncommitted files:

```bash
changed_files=$({ git diff --name-only; git diff --cached --name-only; } | sort -u)
[ -n "$changed_files" ] && printf '%s\n' "$changed_files" | xargs grep -nE 'eslint-disable|@ts-(expect-error|ignore|nocheck)|prettier-ignore' 2>/dev/null
```

Any hit → remove the directive and fix properly. Genuine false positives belong in
`eslint.config.*` — a rule turned off for a named file glob — or in `tsconfig*.json`,
with user approval, never unilaterally.

An `eslint-disable` or `@ts-expect-error` that was already in a touched file is the
same hit when it names a rule routed this session and sits on a function, component
or type this session changed, or on a module-level declaration in a touched module
(`import/no-mutable-exports` → R8 in a globals request; `react-hooks/exhaustive-deps`
→ R10; an `@ts-expect-error` on `return undefined` → R1): it suppresses the rule it
names, so route it as a finding of that rule and delete it with the fix.
"Pre-existing" and "unrelated" are not verdicts for those — a request to make the
linter pass without suppressions is met when the touched functions and the touched
modules' top-level declarations carry none of the routed rules' directives, not when
the one directive the request named is gone and its neighbours keep their `// TODO`.
A directive elsewhere in a touched file, or one naming a rule this session never
routed — `sonarjs/cognitive-complexity` → R3 on the function whose one global read
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
     function does not make that function's eight-linter `// eslint-disable-next-line` this session's
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
   default, never an optional field that may be absent, and an option handed undefined records the error for
   the constructor to return rather than storing it or substituting the default; a
   value parsed in two places has one constructor; a repeated predicate is a method.
   Score each candidate with R1's scorecard: ≥4 → apply the
   move; 2–3 → apply it or record the judgment call in the STATUS block; 0–1 → leave
   it. A candidate is never skipped because the linter is already quiet. Line
   `3 nouns`: each candidate with its score and verdict — `none scored ≥2` when
   nothing qualified, never a blank.
4. **The comment critic.** Spawn one `ts-react-linter-driven-development:comment-critic` (Agent tool, foreground) over
   the touched files with the payload @pre-commit-review step 3b names, and state the
   scope in the spawn prompt as *every comment in each touched file*, not the changed
   lines — the `Sink is where events are written.` JSDoc beside the code just
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
2 re-run     [R3, R1, R8]: [0 hits / file.ts:NN still — routed again]
3 nouns      [Region (score 5) → Replace Primitive with Domain Type applied; Tags (score 2) → recorded]
4 critic     [n] verdicts applied · [n] DELETE → routed R3
5 STOP       [none of the over-engineering signs / undone: <move>]
6 commit     [abc1234 "<message>" / Phase 5 commits the slice / tree clean, nothing to commit]

BROADER CONTEXT
  [file.ts:NN — R3 Q1 — // eslint-disable-next-line on an eight-linter function this session never opened / none]

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
