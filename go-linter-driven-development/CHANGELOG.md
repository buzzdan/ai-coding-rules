# Changelog

All notable changes to the `go-linter-driven-development` plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [2.6.0] - 2026-07-10

### Added

- **Finding clusters — design-first routing for related review findings.** Hunters
  are single-obsession and blind to each other, so when findings from ≥2 different
  rules converge on one anchor (the same type, field/discriminator, or function),
  that independent convergence is evidence of a missing domain concept — a
  juiciness scorecard that filled itself in. Fixing such findings member-by-member
  produces partial patches that undo each other (R1 names an enum that R11's move
  then replaces; R2 places validation that R11's move relocates).
  - `@pre-commit-review` step 4 gains a **cluster pass**: convergent findings are
    reported as first-class 🔗 CLUSTER entries with a root-cause hypothesis and a
    design-first routing note; members stay in their categories, tagged. Clustering
    is reporting — the skill still never edits.
  - The orchestrator's Phase 4 gains **cluster routing**: clusters go to
    `@code-designing` in a new **cluster-scoped mode** (skips the architecture scan
    and user-OK gate — acceptance was inherited when the findings were accepted;
    designs only the one concept the cluster names), then `@refactoring` implements
    the mini plan; member findings resolve as consequences of one design.
    Singletons route directly to `@refactoring`, unchanged.
  - `/go-ldd-quickfix` Phase 4 follows the same routing.

## [2.5.0] - 2026-07-10

### Added

- **`maxims.md` — the uncompiled layer above the rules.** Rules are compiled
  judgment (detection command + violation criterion + fix pattern); maxims are the
  named questions that *generate* such rules in situations no rule anticipated:
  "Tell, don't ask", the Law of Demeter, "Make illegal states unrepresentable",
  "Parse, don't validate", "Duplication is far cheaper than the wrong abstraction",
  "YAGNI", "Three strikes", "A little copying is better than a little dependency",
  "The bigger the interface, the weaker the abstraction", "Make the zero value
  useful" (held in explicit tension with R2), "Make the change easy…", "If a test
  is hard to write, the design is wrong", "If it hurts, do it more often",
  "Premature optimization…", "Clear is better than clever", "Once and only once",
  "Depend in the direction of stability". Each entry: the quote, attribution, the
  question it makes you ask, and the rules that compile it (or *uncompiled* status).
- **The contract: maxims propose, evidence disposes.** Maxims are wired into the
  three judgment points and banned from the evidence path:
  - @code-designing gains `<maxim_interrogation>` — the plan is questioned with the
    maxims before types are committed (design has no diff to grep; questions are
    the only tool there)
  - @refactoring's escalation now frames *why code resists* in maxim vocabulary
  - the `overabstraction-skeptic` cites Metz/Pike/YAGNI by name in verdicts — a
    named principle is an argument, "feels unnecessary" is not
  - the `rule-hunter` evidence protocol explicitly forbids maxim-justified findings
- **Graduation path**: a maxim that keeps generating findings no rule can express
  gets compiled into an R-file — R11 and R4's feature-envy question are graduates
  of exactly this path.
- **The Message Chains ↔ Middle Man pair** (Fowler's opposing smells), compiled to
  its post-Tell-Don't-Ask residue as two R4 fix-pattern bullets: a chain is a
  placement signal (move the behavior; only boundary egress keeps the chain, inside
  the adapter), and a pure-forward method is R1's ceremony verdict applied per
  method (delete forwards that own no rule; domain-type embedding manufactures the
  smell in one line). No R13 — after the behavior moves, nothing detectable
  remains, so the pair is guidance, not a rule.
- **House maxim: "Every indirection must earn its keep"** — the generalized
  juiciness test, named as the plugin's own synthesis: one principle at six
  granularities (type/interface/method/dispatch/guard/copy), enforcement agent the
  `overabstraction-skeptic`; each rule's inverse trap is its retrospective form.

## [2.4.0] - 2026-07-10

### Added

- **Phase 1.5 PREPARE — autonomous preparatory refactoring** (Fowler: "make the
  change easy, then make the easy change"). After the user approves the design plan,
  the orchestrator surveys the plan's touch points with the existing rule detection
  greps and reshapes what the change is about to hit — before the first RED, in its
  own commit(s). Decisions are made by four mechanical gates, never by stopping to
  ask: **MULTIPLY** (only violations the plan would multiply qualify), **SAFE**
  (characterization tests first on uncovered paths), **BOUNDED** (S/M efforts
  proceed, L defers to the Phase 4 report), **SKEPTICIZED** (any extraction is
  judged by the over-abstraction skeptic, scored against the plan in hand).
  Autopilot never pauses; the PREPARATION LOG is a record, not a question.
- **RED-friction escape hatch** (Phase 2): a RED test that resists — fixture
  surgery, global mutation, driving layers to reach a seam — is a prep signal the
  survey missed; suspend the cycle, run the same gates, land the prep commit,
  re-enter RED.
- **`@refactoring` `<preparatory_mode>`**: same routing table and moves, different
  trigger (the plan, not the linter — targets are usually lint-green) and different
  stopping criterion: not "linter green" but "the feature now lands add-only";
  full suite green after every move; prep commits segregated from feature commits.
- **`/go-ldd-prepare <change> [files]`** — standalone entry: describe the impending
  change, get the survey + gates + reshaping without the full five-phase workflow.

## [2.3.0] - 2026-07-10

The Fowler wave — adopting the *Refactoring* (2nd ed.) ideas the rule set didn't
already embody. (Much of the catalog was already here under other names: Extract
Function → R3, Replace Primitive with Object → R1, Repeated Switches → R11,
Speculative Generality → the over-abstraction skeptic, the Two Hats → the
RED→GREEN→REFACTOR loop.)

### Added

- **`rules/R12-mutation-discipline.md`** — Fowler's Mutable Data smell family with
  Go aliasing teeth: a validated value changes state only through methods that own
  its invariants. In Go, `return g.perms` returns a mutable alias into the
  "validated" state — R2's validate-once guarantee is void the moment an internal
  slice escapes. R12 owns:
  - Copy on the Way In — constructors clone slice/map arguments (or build fresh)
  - Copy on the Way Out / Encapsulate Collection — queries return clones or `iter.Seq` iterators, never internal references
  - Separate Query from Modifier — split hybrids; pure naming cases stay with R3's Honest Rename
  - Remove Setting Method — no unvalidated mutation paths around a validating constructor (construction itself stays R2's)
  - Split Variable — one assignment per meaning
  - the inverse trap: ceremony copies of data that never escapes, mirroring R1's over-abstraction symmetry
- **Split Phase move in R3** (Fowler's opening example): a function interleaving
  parsing with computation splits into phase 1 producing an intermediate domain
  structure and phase 2 consuming it — distinct from Extract Function because it
  introduces a data structure *between* the steps; collapses into R2's `ParseX`
  when phase 1 validates.
- **Data Clumps question in R1** (Introduce Parameter Object / Preserve Whole
  Object): the same parameter group in ≥2 signatures is a type asking to exist —
  the scorecard already rewarded grouping; now a falsifying question hunts it.
- **Feature Envy in R4** (Move Function): a new fix pattern (Move Method to the
  Envied Type) and falsifying question — a function reading a foreign type's data
  more than its own moves onto that type, then re-places via the ladder.
- Wiring: pre-commit-review hunts R12 (🔴 Design Debt), code-designing dispatches
  R12 at design time (closed mutation surface in the checklist), refactoring's
  pattern index owns the five R12 moves. R12 has no owning linter (like R9) — no
  routing-table row.



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

[2.6.0]: https://github.com/buzzdan/ai-coding-rules/releases/tag/go-ldd-v2.6.0
[2.5.0]: https://github.com/buzzdan/ai-coding-rules/releases/tag/go-ldd-v2.5.0
[2.4.0]: https://github.com/buzzdan/ai-coding-rules/releases/tag/go-ldd-v2.4.0
[2.3.0]: https://github.com/buzzdan/ai-coding-rules/releases/tag/go-ldd-v2.3.0
[2.2.0]: https://github.com/buzzdan/ai-coding-rules/releases/tag/go-ldd-v2.2.0
[2.1.0]: https://github.com/buzzdan/ai-coding-rules/releases/tag/go-ldd-v2.1.0
[2.0.0]: https://github.com/buzzdan/ai-coding-rules/releases/tag/go-ldd-v2.0.0
[1.0.0]: https://github.com/buzzdan/ai-coding-rules/commit/746ae7d
