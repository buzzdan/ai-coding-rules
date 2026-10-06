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
"Invoke @skill-name" means call the **Skill tool** — `Skill(ts-react-linter-driven-development:code-designing)`,
`Skill(ts-react-linter-driven-development:testing)`, `Skill(ts-react-linter-driven-development:pre-commit-review)` — never just mention
it. This skill runs in the thread that invoked it: its moves are never delegated to a
general-purpose or any other subagent; the one agent it spawns is the comment critic
of step 4 below.
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
| A tuple return (`[T, boolean]`, `[Data, Error]`); a `Record<string, string>`, `string[]` or `Map` of primitives crossing a function boundary or nested in a type (review-only) | `../../rules/R1-primitive-obsession.md` (Name the Container — Q7 nested, Q8 flat across a boundary; the receivers' lookups, filters and loops are the methods of the type that does not exist yet) |
| `sonarjs/no-duplicate-string` on an enum-shaped literal; `no-magic-numbers` on a domain value; `sonarjs/max-union-size` | `../../rules/R1-primitive-obsession.md` (Name enum strings, or a named type) |
| `sonarjs/no-identical-functions`; duplicated code (review-only) | `../../rules/R1-primitive-obsession.md` (extract shared type/logic); duplicated `switch`/if-chains on the same kind/type discriminator → `../../rules/R11-conditional-dispatch.md` |
| `sonarjs/max-lines` (600) | `../../rules/R5-vertical-slice.md` — mechanics in `<file_and_package_routing>`, `sed -n '/^## File and package routing/,/^## Preparatory mode/p'` over this skill's `reference.md` |
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
(Phase 1.5, or RED friction) or `/tsr-ldd-prepare` with a DESIGN PLAN, the
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
   box? A slice walked with flags is a collection type over it (R1); a container of
   primitives handed across a boundary and looked up or filtered by its receivers is
   a type with no name (R1, Name the Container); an optional
   collaborator is a Null Object default; a value parsed twice has one constructor; a
   repeated predicate is a method. Score each with R1's scorecard: ≥4 apply; 2–3 apply
   or record the judgment call; 0–1 leave. Line `3 nouns`: each candidate with score
   and verdict — `none scored ≥2` when nothing qualified, never a blank.
4. **The comment critic.** Spawn one `ts-react-linter-driven-development:comment-critic` (Agent tool,
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
2 re-run     [R3, R1, R8]: [0 hits / file.ts:NN still — routed again]
3 nouns      [Region (score 5) → Replace Primitive with Domain Type applied; Tags (score 2) → recorded]
4 critic     [n] verdicts applied · [n] DELETE → routed R3
5 STOP       [none of the over-engineering signs / undone: <move>]
6 commit     [abc1234 "<message>" / Phase 5 commits the slice / tree clean, nothing to commit]

BROADER CONTEXT
  [file.ts:NN — R3 Q1 — // eslint-disable-next-line on an eight-linter function this session never opened / none]

STATUS: [linter green / still failing: N issues / escalated to @code-designing]
```
Every `Stop check` line renders, in this order, opening with its number and keyword
exactly as shown — `1 gates` … `6 commit` — with its result on the same line; a missing
line means the step did not run and the STATUS is not final. `BROADER CONTEXT` lists
every hit step 2 reported rather than fixed, or `none`. Who invokes this skill and what
it invokes: `sed -n '/^## Integration/,/^## Multi-rule procedures/p' <this skill dir>/reference.md`.
</output_format>
