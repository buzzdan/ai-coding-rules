# Changelog

All notable changes to the `ts-react-linter-driven-development` plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
