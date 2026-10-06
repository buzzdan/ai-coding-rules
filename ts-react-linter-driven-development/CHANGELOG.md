# Changelog

All notable changes to the `ts-react-linter-driven-development` plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [2.0.1] - 2026-10-06

### Added

- **The review routes files of another language to the plugin installed for it.**
  The scope script tells each file's language by its extension and writes one bundle
  per language group: TypeScript and JavaScript are reviewed here; Go goes to
  `go-linter-driven-development` and Python to `python-linter-driven-development`
  when installed; any other language goes to `linter-driven-development` when
  installed; a group no installed plugin reviews is named file by file with the
  reason, never dropped. The detection pass runs once per group with the reviewing
  plugin's rules, and the report is one report with a section per language. A
  TypeScript-only diff writes the same flat bundle as before. `--lang` reviews one
  group only, the flag a plugin passes when it routes a group here.
  `scripts/ldd-scope_test.sh` is the scope script's own fixture matrix.

## [2.0.0] - 2026-10-06

### Changed

- **Generated from the shared core.** The plugin is rendered from the same core as
  `go-linter-driven-development` and `python-linter-driven-development` — twelve
  rules, the maxims, the design, TDD, refactoring, testing, review and documentation
  skills, the hunter/skeptic/critic review and the repo-brain gate — with TypeScript
  and React knowledge. Every canonical example is TypeScript in a React repository;
  every falsifying question carries a detect line over `.ts` and `.tsx` files.
- **`@component-designing` is `@code-designing`.** The design skill carries the
  core's name; the other five skill names are unchanged.
- **No `CLAUDE.md` in the plugin directory.** The 1.x file that instructed Claude to
  invoke the orchestrator for every change is gone; the orchestrator skill
  auto-triggers in a React project instead.
- **Commands carry the `tsr-ldd` prefix.** `/tsr-ldd-autopilot`, `/tsr-ldd-quickfix`,
  `/tsr-ldd-prepare`, `/tsr-ldd-analyze`, `/tsr-ldd-review`, `/tsr-ldd-status`;
  `/wire-repo-brain` stays unprefixed, as in the Go and Python plugins.

### Added

- **The twelve rules** under `rules/`, R1-primitive-obsession through
  R12-mutation-discipline, each a self-contained hunter rulebook with a TypeScript
  canonical example and a detect line on every falsifying question.
- **The review's detection pass and scope bundle are scripts.** `scripts/ldd-scope.sh`
  writes the bundle from the review's scope rung — a file list, the working tree, the
  branch against its base, or the whole repository — with the added comment lines
  the critic judges in `comments.txt`, and prints one summary line.
  `scripts/ldd-detect.sh` runs every detect line over the bundle and writes
  `hits.tsv`, `hits-all.tsv` and `counts.tsv`, with the suppression scan as a row;
  two runs over one tree write identical counts. Every falsifying question in
  `rules/R1` to `R12` carries a detect line beside its prose — a `grep` pattern over
  `.ts` and `.tsx` files, a `path` pattern over their paths, a reference to one of
  the R9 gate's questions, or the word `judgment` for a question the hunter can only
  read. The pre-commit review's first step runs both scripts and reads the counts
  table they print; a rule family with a hit gets one hunter carrying its rule files
  by path and its family's rows of the hits table, and the comment critic reads the
  bundle's comment lines as its inventory. What each question asks is unchanged.
- **R1 catches containers of primitives.** Two falsifying questions: Q7, a nested
  container in a signature or a field (`Map<string, string[]>`,
  `Record<string, Record<string, number>>`), always a finding; Q8, a flat
  `string[]`, `Record<string, string>` or tuple crossing a function boundary, judged
  by what its receivers do with it — a lookup, a membership test, a loop that
  filters and extracts, each one a method of a type that does not exist yet. The
  move is **Name the Container**; the lint-fixer's routing table, the refactoring
  routing table and the design skill's linter triggers carry it as a review-only
  row, because ESLint has no rule for it.
- **R7's mutation question.** Q7 asks whether a mutant survives a leaf type's
  tests: coverage is the floor, the mutation score the claim, and the move is Kill
  the surviving mutant. The TypeScript mechanics name Stryker — `npx stryker run`
  with `mutate` naming leaf modules only, never pages, hooks or the whole `src/`
  tree — and every survivor is triaged as a missing `it.each` row, dead logic or a
  recorded equivalent mutant. The workflow's pre-flight discovers a `mutate` or
  `stryker` target beside the test and lint commands, and the testing reference's
  checklist carries the row.
- **`coding-rules/ts-react.md`, the TypeScript + React coding-rules handbook.** The
  twelve rules with TypeScript examples and the binding's positions as asides, the
  house rules with their TypeScript spelling, a self-review checklist and the
  mechanics; generated from `core/handbook/` and `lang/ts-react/handbook/` in the
  same run as the plugin, and read by a team that does not develop with it.
- **Nine positions where the rules meet TypeScript and React idiom**, recorded in
  the main repository's `docs/language-residue.md`: `undefined` is the declared
  absence and `null` stops at the boundary; an optional collaborator is a module
  constant supplied by a destructuring default; a self-validating type is the one
  function that builds the value, `parseX(raw: unknown)` at the boundary and
  `readonly` fields after; the JSDoc summary line is the contract; the kept switch
  is over a discriminated union closed by `assertNever`; effects, timers and queries
  have owners and cleanups, and the race is the stale closure and the out-of-order
  response; module state is silent for constants and types, silent in `main.tsx`
  for configuration and wiring, and reported everywhere else; a component is an
  orchestrator whose logic lives in hooks and pure functions placed by R4's ladder;
  MSW is the real layer for HTTP and `vi.mock` of an internal module is R6's seam.
- **Linter routing keyed by ESLint rule ids.** The SonarJS complexity family and
  `react/no-unstable-nested-components` route to R3, `max-params` to R1,
  `sonarjs/max-lines` and `react/no-multi-comp` to R5, the typescript-eslint
  `no-unsafe-*` family at a boundary to R2, exhaustiveness and nested switches to
  R11, `react-hooks/*` and the floating-promise rules to R10,
  `import/no-mutable-exports` to R8, `no-param-reassign` and
  `sonarjs/prefer-read-only-props` to R12. Every suppression form —
  `eslint-disable` in all its spellings, `@ts-expect-error`, `@ts-ignore`,
  `@ts-nocheck`, `prettier-ignore` — is one the lint-fixer never adds.
- **The agents**: `rule-hunter`, `overabstraction-skeptic`, `comment-critic` and
  `lint-fixer`, each spawned in an isolated context and pointed by path at its rule
  files — a hunter gets its rule family's, four hunters at most, with its family's
  rows of the detection pass's hits table; the critic gets the bundle's comment
  lines.
- **Seven slash commands**: `/tsr-ldd-autopilot`, `/tsr-ldd-quickfix`,
  `/tsr-ldd-prepare`, `/tsr-ldd-analyze`, `/tsr-ldd-review`, `/tsr-ldd-status` and
  `/wire-repo-brain`.
- **Repo-brain gate with the TypeScript adapter.** `scripts/check-repo-brain.sh`
  resolves backticked symbols against functions, variables, classes and their
  members, interfaces, types and enums, owned by their module and their directory;
  a `package.json` directory outside `node_modules` marks a sub-project.
- **The six case studies under `examples/`, in TypeScript.** The over-abstraction
  rejection is a `readonly` config against a `CIDRPresence` wrapper; the storify
  case extracts an `IPConfig` leaf from a settings hook; the anti-if case dispatches
  through a `Record<Channel, …>` and a `switch` closed by `assertNever`; the
  switch-to-polymorphism case moves `fillUpdate` onto the patch kinds; dependency
  rejection replaces `import.meta.env` reads with one `AppConfig` built in
  `main.tsx`; the comment-noise verdicts fall on non-exported JSDoc.

### Removed

- **The hand-written six-skill text.** The 1.x `SKILL.md`, `reference.md` and
  `examples.md` files are replaced by the rendered core; nothing from them is
  carried over verbatim.
- **Storybook generation as a documentation step.** A story is the runnable example
  only where the repository has Storybook; the documentation skill no longer
  writes `.stories.tsx` files on its own.
- **The accessibility review checklist.** Accessibility is enforced in the linter
  phase through the repository's `jsx-a11y` configuration, where a failing rule is
  a mechanical fix, not a review hunter's finding.

### Measured against 1.x

Both plugins reviewed the `ts-react-mini` eval fixture (164 planted violations and
controls, in [buzzdan/ldd-evals](https://github.com/buzzdan/ldd-evals)) under the
same prompt and model (`claude-sonnet-5`): eight review cases whose prompt names no
slash command and whose graders carry no rule ids, then refereed finding by finding
against the manifest, by substance.

- **Whole repository.** 1.x found 53 of the 129 planted diseases a review must find,
  2.0 found 89: 42 by both, 11 by 1.x alone, 47 by 2.0 alone, 29 by neither. False
  positives on the 30 controls: 3 against 1. Cost $3.22 against $6.30.
- **Scoped cases.** 2.0 found as many or more in six of seven (retention 4/3,
  endpoint 4/2, ceremony 4/2, optional collaborators 6/4, globals 4/4, the
  798-line centerpiece 34/11 of 45); 1.x was ahead on the placement picker (3/2).
- **What 2.0 sees that 1.x never names:** tests (fused success/error tables, call
  counts on doubles, sleep-then-assert, `vi.mock` of an internal hook beside MSW
  handlers), test seams (an interface with one production implementer, hand
  doubles, a false "avoids an import cycle"), documentation (the orphan doc, its
  `file:line` citation and phantom symbol, the unwired `CLAUDE.md`), suppressions
  as findings, the comment critic's verdicts, role-named directories and the
  layer-versus-slice split, and three concurrency plants (an interval started in a
  constructor and never cleared, a check-then-await race, bare sleeps in retries).
- **What 1.x sees that 2.0 does not:** accessibility (no hunter owns it; 2.0 relies
  on the repository's `jsx-a11y` rules, which the fixture disables as the house
  style does), and the React tree in the whole-repository run, where 2.0's types
  hunter declared partial coverage and did not reach `components/`, `hooks/` or
  `pages/DeviceView/`, so the nested-component, prop-drilling and sort-in-render
  plants went unseen rather than misjudged. 1.x also raised several real bugs
  outside the manifest (a cross-tenant `lastSeen` key, a score recomputed by hand
  and drifting, `NaN` passing a port check).
- **2.0 weaknesses the run exposed:** it asserted a test file was missing that exists
  (picker), it rewrote the one WHY comment the ceremony case protects, and its
  whole-repository coverage is partial at 167 files.

## [1.2.0]

- The hand-written plugin: six skills (`@linter-driven-development`,
  `@component-designing`, `@testing`, `@refactoring`, `@pre-commit-review`,
  `@documentation`), a `CLAUDE.md` enforcing the workflow, Jest or Vitest with
  React Testing Library, Storybook stories as documentation and an accessibility
  checklist inside the review.

## [1.1.0]

- Earlier hand-written release of the six-skill plugin; no changelog was kept
  before 2.0.0.

## [1.0.0]

- Initial hand-written release of the six-skill plugin.
