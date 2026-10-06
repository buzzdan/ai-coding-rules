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
  every falsifying question says what to grep in `.ts` and `.tsx` files.
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
  R12-mutation-discipline, each a self-contained hunter payload with a TypeScript
  canonical example.
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
  `lint-fixer`, each spawned in an isolated context with its rule as payload.
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
