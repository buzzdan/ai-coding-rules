# Changelog

All notable changes to the `go-linter-driven-development` plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [2.2.0] - 2026-07-10

### Added

- **`rules/R11-conditional-dispatch.md`** — the Anti-IF rule, adapting the Anti-IF
  movement's core insight (Cirillo, 2007) to the rules-as-data architecture: a
  conditional that asks what a value *is* may exist once; the second copy of a
  kind/type discriminator is a missing polymorphic type. R11 owns:
  - Replace Duplicated Switch with Interface Dispatch — variants become leaf types, the decision moves to a `ParseX` boundary constructor (R2's behavioral twin: *decide* once at the edge)
  - Replace If-Chain with Strategy Map — single-behavior variance dispatches through a map, comma-ok at the boundary only
  - Introduce Null Object and Split Flag Argument
  - the sanctioned form: Keep the Single Exhaustive Switch — one site over a closed enum stays, named per R1 and proven complete by the `exhaustive` linter
  - the inverse trap: dispatch abstractions that delete no duplication are ceremony — one switching site with trivial variance keeps its switch (mirroring R1's over-abstraction symmetry and R6's earned-interface test)
- **`examples/anti-if-dispatch.md`** — case law: a three-site channel switch (already
  drifted) collapsed to interface dispatch, the strategy-map variant, and the worked
  rejection where the skeptic kills the extraction and the switch goes exhaustive
  instead. Pasted to the skeptic alongside R11 dispatch proposals.
- **`examples/switch-to-polymorphism.md`** — second R11 case file (real production
  code), the type-switch sibling of anti-if-dispatch: an already-polymorphic value
  un-dispatched by a field-unpacking type switch becomes a fill-style interface
  method. Covers the tempting wrong fix (extract-per-case as ceiling, not cure),
  fill-don't-construct ownership, the earned + sealed interface (R6), and the
  dependency-direction rejection — orthogonal to the juiciness rejection — where
  the consumer owns the wire format and the switch legitimately stays as pure
  dispatch.
- Wiring: pre-commit-review hunts R11 (🔴 Design Debt), its dispatch proposals face
  the over-abstraction skeptic with the new case file as payload, code-designing
  dispatches R11 at design time (one dispatch owner per variant family in the
  checklist), refactoring + lint-fixer route `exhaustive` failures and
  discriminator-shaped `dupl` hits to it.

## [2.1.0] - 2026-07-07

### Added

- **`rules/R10-concurrency-safety.md`** — restores the concurrency coverage that v2.0.0 dropped when the generalist reviewer was retired (v1's "Design Bugs" checklist §8 and anti-patterns §9 had no rule home). R10 owns what static analysis cannot prove:
  - every goroutine has an owner (stop + wait) and a provable exit path
  - shared mutable state is guarded where it lives (mutex next to the data, or confined/handed off)
  - no `time.Sleep` on cancellable production paths — timer `select` with `ctx.Done()`
  - the inverse trap: guards and goroutines that are ceremony (single-goroutine mutexes) get deleted, mirroring R1's over-abstraction symmetry
- Wiring: pre-commit-review hunts R10 (leaks/races categorized as 🐛 Bugs; sleeps/ownership/mutex-placement as 🔴 Design Debt), its "Extract Synchronized Owner" proposals face the over-abstraction skeptic, code-designing dispatches R10 at design time, refactoring + lint-fixer route `go test -race` failures and `govet copylocks` to it.

### Explicitly out of R10's scope

Mechanical error-handling checks (ignored errors, unclosed response bodies, copied locks) stay with the linter — `errcheck`, `bodyclose`, `govet` — per the "linter says WHAT" division. Judgment-level silent-failure review (fallback legitimacy, error-message quality) is served by external review tooling, not duplicated as a rule.

## [2.0.0] - 2026-07-07

The **rules-as-data** release. The unit of knowledge is now the rule, not the phase: each design principle lives exactly once in `rules/`, and every skill, agent, and command is a thin view or worker over those rules.

### Breaking

- **Removed the `quality-analyzer` and `go-code-reviewer` agents.** Anything that invoked them directly ("use the quality-analyzer agent", custom commands, references in your CLAUDE.md) will fail with "unknown agent".
  **Migration:** `/go-ldd-analyze` replaces quality-analyzer's combined tests+lint+review report; `@pre-commit-review` replaces go-code-reviewer with the hunter/skeptic review.

### Added

- **`rules/` — R1–R9, the single source of truth.** Each rule file states its Principle, Why, a canonical before/after, Design guidance (forward), a Fix pattern (backward), and Falsifying questions with grep-able detection commands:
  R1 primitive obsession · R2 self-validating types · R3 storifying · R4 helper placement · R5 vertical slice · R6 test-only interfaces · R7 test placement · R8 no globals · R9 repo-brain (documentation network).
- **`examples/` — case law.** Deep worked studies cited by the rules: `storify-leaf-type`, `overabstraction-cidr`, `dependency-rejection`.
- **New agents** (spawned programmatically, payload-fed, isolated contexts):
  - `rule-hunter` — single-obsession reviewer; gets ONE rule file pasted in full, hunts only that rule across the diff, returns evidence-backed findings.
  - `overabstraction-skeptic` — devil's advocate that tries to kill every "extract a type/package" proposal using R1's juiciness scorecard; refuted proposals ship a cheaper alternative instead.
  - `lint-fixer` — runs the full-repo lint-fix loop in an isolated context (token noise stays out of your conversation); fixes mechanical issues, escalates design failures with a rule route.
- **`/wire-repo-brain [path]` command** — bootstrap the R9 documentation network on an existing repo in one pass: code→docs edges, `index.md`, CLAUDE.md wiring.
- **Composition-ladder testing model** in `@testing`: test each behavior at the lowest rung that contains it; rung-tagged reusable patterns in the testing reference.

### Changed

- **Review is now hunter/skeptic and advisory.** `@pre-commit-review` grep-prefilters the diff per rule, spawns one parallel `rule-hunter` per rule with hits, then the skeptic pass; the merged report categorizes findings (🐛 Bugs / 🔴 Design Debt / 🟡 Readability / 🟢 Polish) and **never blocks a commit**. Expect more parallel subagent activity during review than v1's single reviewer.
- **The orchestrator runs a per-behavior RED→GREEN→REFACTOR loop** (Phase 2) with package-scoped lint each cycle, instead of phase-batched implementation. Full-repo lint runs once, in Phase 3, via `lint-fixer`.
- **Skills were thinned to directional views** (~100–150 lines) that sequence and route into the rules — `@code-designing` is the forward view (design before code exists), `@refactoring` the backward view (linter failure → owning rule's Fix pattern). Duplicated reference content was deleted; skill names are unchanged.
- **`@documentation` is now the R9 repo-brain author** with FEATURE mode (Phase 5, document behavior after a change) and BOOTSTRAP mode (wire a repo's documentation network).
- Commands (`/go-ldd-analyze`, `/go-ldd-autopilot`, `/go-ldd-quickfix`, `/go-ldd-review`, `/go-ldd-status`) updated to the new phase model; names and file-targeting behavior unchanged.

### Unchanged — no action required on upgrade

- Plugin name, all six skill names, all five pre-existing slash commands, auto-detection triggers, and the zero-configuration promise (test/lint commands discovered from Makefile/Taskfile/README).
- The opt-in package-size hook.

## [1.0.0] - 2025-10-28

Initial release as a Claude Code plugin: five-phase linter-driven workflow (design, TDD, lint, review, document) with skills, the `quality-analyzer`/`go-code-reviewer` agents, `/go-ldd-*` commands, and the package-size hook.

Notable unversioned improvements between 1.0.0 and 2.0.0: auto-pilot mode and review agent commands, evidence-based review with test-only interface detection, self-validation ownership rule, improved lint-failure flow, and making the package-size hook opt-in.

[2.2.0]: https://github.com/buzzdan/ai-coding-rules/releases/tag/go-ldd-v2.2.0
[2.1.0]: https://github.com/buzzdan/ai-coding-rules/releases/tag/go-ldd-v2.1.0
[2.0.0]: https://github.com/buzzdan/ai-coding-rules/releases/tag/go-ldd-v2.0.0
[1.0.0]: https://github.com/buzzdan/ai-coding-rules/commit/746ae7d
