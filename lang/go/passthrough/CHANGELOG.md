# Changelog

All notable changes to the `go-linter-driven-development` plugin are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- **The review's waiting rules name the real mechanism.** Hunters are spawned together
  as foreground `Agent` calls and their results return in the same message; the skeptic
  and the critic share one hunter-free message; the review never polls
  (`ReadNotifications`, `ListAgents`, `Monitor`, scheduled wake-ups). Earlier drafts of
  this entry blamed an omitted `run_in_background` flag, then a foreground quota, and
  capped hunters at six per message; all three were wrong about the cause. A Claude Code
  cloud session exports `CLAUDE_AUTO_BACKGROUND_TASKS`, under which the harness turns any
  foreground call still running after 120 seconds into a background task answered "Async
  agent launched" — every such conversion in the eval traces sits at exactly 120.0 s,
  whatever the batch size — and the eval runner passed that flag through to the agent
  under test. On a developer's shell the flag is unset and a foreground call blocks until
  the hunter returns; with the flag stripped, three whole-repository reviews ran in one
  segment each with no polling (98, 98 and 86 of 111 recall graders, against 94–95
  before). The skill now says what a cloud session does and that an auto-backgrounded
  hunter's result arrives by itself, never polled for and never re-spawned; the
  six-per-message cap is gone.
- **Review and analyze resolve their scope by one ladder, and never widen it.** An
  explicit argument names the scope (`--all` for the whole repository — the only way to
  get a whole-repository audit); otherwise the working tree's changes against `HEAD`;
  otherwise, with a clean tree, the current branch against its base (the merge-base with
  `origin/main`, `main` or `master`), which is the ceiling; otherwise "nothing to review",
  named as such, with no hunters and no verdict over an empty scope. Before, `/go-ldd-review`
  inherited the review skill's "staged changes by default" and `/go-ldd-analyze` fell back
  to every `.go` file when nothing had changed, so a clean tree produced either an empty
  certified review or an unrequested whole-repository audit depending on the run. The
  `pre-commit-review` skill states the same contract for its diff-scope input.
- **R2: the Null Object is named and no argument is nil.** The 2.10.1 example
  defaulted a nil `sink` inside the constructor, which keeps `NewReporter(nil)`
  legal and only relocates the nil-check; the first re-run of the nil-handling
  refactor on 2.10.1 reproduced exactly that shape. The example now supplies
  `DiscardSink()` through an option and the fix move says the default is named and
  passed, never inferred from nil. The refactoring skill's move table carries the
  same line, because the second re-run reached the option shape and then introduced
  a one-implementation `Sink` interface for the no-op: the agent applying the move
  reads the skill, not only the rule.

## [2.10.1] - 2026-09-11

### Changed

- **R2 and R11: absence is a value.** R2 gains the design point and the fix move
  the review was missing: an *optional* collaborator (logger, sink, clock, metrics)
  is never a nil-able field with a guard in every method — the constructor
  substitutes a do-nothing value (Introduce Null Object, R11), and only a
  *required* collaborator is rejected in the constructor. R2's falsifying questions
  Q2 and Q6 name that fork so a hunter routes each finding to the right move. R11's
  Null Object entry now states the Go shape: a no-op implementation only when an
  interface already exists, otherwise a value of the concrete type composing
  `io.Discard` (the standard library's own Null Object), and never a new interface
  for the sake of the no-op (R6). Motivated by the go-2.10.0-5828c34 eval baseline,
  where both nil-handling reviews proposed "reject nil in the constructor" for an
  optional sink and the refactor introduced a one-implementation interface.

### Internal

- **Generated plugin directory**: the plugin's source now lives in the
  repository's `core/` (language-neutral text) and `lang/go/` (the Go binding:
  profile scalars, include snippets and files copied through), and
  `tools/ldd-gen` renders them into this directory. The rendered files are
  byte-identical to the hand-written ones they replace; nothing an installed
  plugin sees changes.

### Added

- **Behavioral evals**: the plugin's skills, agents and workflow are measured by
  eval cases in the `claude plugin eval` format that run the plugin against a
  deliberately bad Go service planting every R1–R12 falsifying question at least
  once, with a control per rule. The cases, fixture, runner and baselines live in
  the separate [buzzdan/ldd-evals](https://github.com/buzzdan/ldd-evals)
  repository so an installed plugin carries none of them. This repository keeps
  `evals/README.md` as a pointer, `scripts/evals.sh` to clone and run a tier
  against the current checkout, and `docs/` describing the mechanism. Two
  baselines on plugin 2.10.0 are recorded there: `baselines/go-2.10.0-681fdb0/`
  on the hand-written plugin and `baselines/go-2.10.0-5828c34/` on the generated
  one, the current reference, which the R2/R11 change above answers.

## [2.10.0] - 2026-08-20

The repo brain had one audience: a session with this plugin installed. In a
monorepo most contributors — and their agents — don't have it, so the network's
rules lived nowhere they could find and nothing enforced them. This release
makes the doc root a standard, self-describing artifact: an Open Knowledge
Format (OKF v0.2) bundle any tool can consume, with its own maintenance manual
inside and a CI gate outside.

### Added

- **OKF v0.2 bundle conformance (R9)**: content docs carry YAML frontmatter —
  required `type` (the spec's one required key) and `description`; optional
  `title`/`generated` (OKF's provenance key)/`tags` and lifecycle
  `status`/`stale_after`, the frontmatter-native form of the ⚠️ stale flag.
  Indexes stay bare, as the spec reserves them; the root index carries only
  `okf_version`. R9 is a stricter profile of the spec built from spec-valid
  keys, so the bundle stays consumable by any OKF tool. New falsifying
  question **Q7** checks the bundle contract mechanically.
- **Drift-check rule (R9)**: a doc's index line IS its `description`, copied
  verbatim — the description is the single source, and the conformance gate
  fails when the copy drifts; `check-repo-brain.sh --fix` rewrites drifted
  lines from the descriptions (the one mechanical repair the gate performs).
  The map of maps is directory-shaped (per-topic subdirectories with their
  own bare index.md), and the split lands in the same commit as the
  `See docs/...` path rewrite.
- **One-way link policy (R9)**: write an edge only when no structure implies
  it — no child→parent backlinks, no `related:` frontmatter key, no `## Related`
  section; lateral links go inline with the reason in the sentence. `log.md` is
  never emitted.
- **Self-hosting conventions doc**: BOOTSTRAP creates `<docroot>/conventions.md`
  (template in reference.md) — the network's maintenance rules written for
  contributors without this plugin, listed first in the index.
- **AGENTS.md routing block**: upgraded from "fallback when CLAUDE.md is
  absent" to first-class multi-tool coverage — root and nested per sub-project
  (closest file wins), pointing every AGENTS.md-reading agent at the index and
  conventions.md. Authored once: CLAUDE.md embeds it via `@AGENTS.md` (plus the
  `@<docroot>/index.md` map import) instead of duplicating the routing prose.
- **New `scripts/check-repo-brain.sh`**: dependency-free conformance gate
  running Q1–Q3 and Q7 over every doc root (repo root plus each go.mod
  sub-project): transitive reachability from the root index, both edge
  directions, the file:line ban (URL spans, fenced code blocks, and glob
  patterns exempt), exact-path root wiring (missing AGENTS.md routing is an
  advisory, matched as a fixed string so dotted doc roots never ride a
  look-alike path), the full frontmatter contract (termination; `type` valued
  feature/architecture/guide; a non-empty `description`; bare indexes;
  root-only `okf_version`, exactly one, valued `"0.2"`), every index line
  checked against its target's `description`, and the lifecycle advisory (a
  target stale by `status: deprecated` or a past `stale_after` whose index
  line lacks ⚠️). A link into a missing directory is a broken link, never a
  skip. Docs→code resolution is set-based and Go-shaped: one pass builds the
  repo's declaration set — single-line and grouped `type (`/`var (`/`const (`
  declarations, functions, methods, plus `pkg.Ident`/`Type.Method` ownership
  pairs, so a qualified token resolves only against its actual owner; a
  token missing there still resolves as a whole word in any non-markdown repo
  file (config keys, alert names); external `pkg.Sym` (stdlib, dependencies)
  is exempt. Dogfooded on a 1,271-file production repo: ~55 s per run, zero
  false-positive classes left. BOOTSTRAP installs it into
  target repos and suggests the
  one-line CI wiring. Exit 0 clean/not-adopted, 1 violations, 2 usage error or
  internal scanner failure (a failed scan is inconclusive, never silently
  clean); every failure message points at conventions.md. Everything
  language-specific in the gate sits in one delimited adapter block behind a
  small `LANG_*` / `lang_*` contract; the driver around it (Q1, Q3, Q7, doc
  links, `--fix`) is language-agnostic. Portable across awks (gawk, mawk, BSD
  awk).
- **New `scripts/check-repo-brain_test.sh`**: the gate's fixture matrix as a
  committed test — 35 cases across Q1/Q2/Q3/Q7, `--fix` round-trips, usage
  errors, and the no-code scope, built from POSIX tools in a temp dir. Its
  differential mode (`GATE_REF=<other script>`) fails on any output, exit-code,
  or `--fix` difference between two versions of the gate — the contract a
  refactor, or another language's adapter, must meet.

### Changed

- **BOOTSTRAP is now a migration pass too**: frontmatter is verified-or-added
  on content docs (never duplicated) and stripped from indexes, so a network
  wired by an older plugin version converges to the current rules in one
  idempotent re-run; an un-inferable `type` goes to the advisory report, never
  guessed.
- **Feature Doc Template's `Related` section removed**: lateral doc links go
  inline, in the sentence that states the relationship — a relationship that
  cannot find a sentence in the body is not worth an edge.

## [2.9.1] - 2026-07-23

A real 143-line file surfaced the gap v2.9.0 left open: every one of its nine
unexported symbols carried a comment — one of them 22 prose lines — because the
tier budget caps a comment's size but nothing decided whether it should exist.

### Added

- **Visibility default (R9)**: unexported symbols get NO comment. The name is
  the documentation; a name that needs a comment wants a rename or an
  extraction (R3) first. The special case is ONE line carrying a very
  high-value toolbox item — an ordering constraint, an external library
  quirk, the WHY of a magic number, the package's one real policy. Anything
  more belongs to the exported caller, the package doc, or the feature doc.
  The tier table now explicitly prices exported API only.
- **New case file `examples/private-comment-noise.md`**: the nine-helper file
  with per-symbol verdicts (four one-liners survive, five comments deleted;
  ~68 comment lines become 4) and the full "after". Its path rides in the
  comment-critic's spawn payload from both @pre-commit-review and
  @documentation.
- **New anti-toolbox entry: review-defense narration** — the writer arguing
  with an imagined reviewer ("bounds-checked: it never indexes an empty
  slice", "deliberately narrow — not a generalized table"). The code shows
  its own safety; a design choice worth defending is defended in the feature
  doc.
- **Critic bias for unexported symbols**: the question is existence, not
  size — default verdict DELETE; TRIM down to the one high-value line only
  when it already exists in the comment; never propose growing a private
  comment.
- **@documentation writes accordingly**: FEATURE step 3 now writes godocs for
  exported symbols only by default.

## [2.9.0] - 2026-07-23

Lessons from a repo owner's hard review of a large generated PR: the reviewer
could merge the code but "could not reasonably ask another human to maintain
the result". Two themes: comments that need the code (or a decoder ring) to be
understood, and a feature PR that silently adopted new engineering practices.

### Added

- **Empathy test — the plain-English test grows teeth** (R9 test 3, renamed
  plain-English/empathy test). New persona anchor: write for a fresh graduate
  whose first language may not be English. New failure modes: unexplained
  acronyms and insider jargon ("DTO", "tristate") in comments AND in the symbol
  names they document; and **self-standing** — a comment must be understandable
  BEFORE reading the code ("if I need to read the code to understand the
  comment, the comment adds negative value"); forward references to other
  comments fail. The comment-critic now reads each comment before the
  surrounding code so the self-standing check is built into its protocol.
- **Decoder-ring references join the provenance anti-toolbox** (R9 floor +
  toolbox catalog + critic): plan/decision/test-plan IDs ("T-04-02", "D-07"),
  requirement tags ("REQ-SVC-01"), spec section refs ("spec §4") fail even
  when they resolve inside a repo doc — the fact goes in the comment as plain
  prose, the doc through one See-edge, the ID stays in the doc. Worked ❌/✅
  example (`userResponse`) added to the catalog.
- **Restated repo idiom is a floor failure mode** (R9 + catalog + critic): a
  comment justifying a convention the repo applies everywhere (pointer field =
  "omitted vs explicit zero") is noise even though it is technically a WHY —
  the convention lives once at rung 2. The critic greps the repo for the same
  pattern before crediting such a rationale.
- **See-edge placement rule** (R9): the `See docs/<feature>.md` line is free
  under the budget ONLY as its own trailing line; a doc reference braided into
  the summary sentence is clutter, not an edge.
- **When-in-Rome check** (@pre-commit-review step 1 + new 🟠 New Practice
  category + new maxim): anything the diff introduces that the host repo does
  not already use — test mechanisms (golden files), dependencies, tools, config
  conventions, repo-level file edits bundled into a feature diff — is flagged
  as an adoption decision that belongs to the repo owner; the fix is a
  discussion or a separate PR, never silent inclusion. Detection is
  comparative: grep the repo outside the diff for prior use.
- **Two new maxims**: "Empathy is a core engineering value" (borrowed from a
  reviewer's coding standards) under Clarity and knowledge; "When in Rome,
  code as the Romans do" under Process and economics.
- **Name-jargon note in the critic**: renames are not the critic's to order,
  but when the empathy test fails because the jargon lives in the symbol name
  itself ("DTO"), the verdict block carries a rename recommendation for the
  caller to route. (Added after a live run where the critic rewrote a comment
  but left the jargon name unremarked.)

## [2.8.0] - 2026-07-20

### Added

- **Comment Value Toolbox + comment-critic — comments now have an adversarial
  reviewer.** Reviewers reported ldd-written comments as noise: restated code,
  filled templates, no context. Root cause was architectural: @pre-commit-review
  runs in Phase 4, @documentation writes godocs in Phase 5 — comments were never
  adversarially reviewed, only self-checked by their writer.
  - **The Comment Value Toolbox**: a named, growable catalog of the ways a comment
    delivers value — WHY-not-WHAT, wider context, use cases/flows, boundary
    contract, guarantees, network edge. Normative kinds list in R9's comment
    policy; the catalog with worked examples lives in @documentation's
    reference.md and is designed to grow.
  - **Three-test standard** (normative in R9): toolbox-value (floor: a prose line
    delivering no toolbox value is cut; ceiling: the comment must carry the
    highest-value items for its symbol's tier — short-but-dodging fails too),
    tier budget (from v2.7.0), and plain English (everyday words, short
    sentences — not all readers are native speakers; applies to godocs AND
    feature docs). The floor names **provenance** a failure mode — PR numbers,
    review items, "the previous behavior" narration — under the 5-year reader
    lens: readers care how the product behaves now, not which review round
    produced it; history is rewritten as present-tense rationale, and
    incident/ticket refs survive only as rationale. Falsifying questions
    unchanged.
  - **New `comment-critic` agent**: read-only, single obsession — comment value.
    Judges every comment in the diff (godoc, in-body, test) against the three
    tests; verdicts KEEP / TRIM / REWRITE / DELETE with evidence; every rewrite
    names the toolbox item it delivers. In-body block-narration comments route to
    R3 (extraction candidates). Adversarial default: uncertain → fails.
  - **@documentation closes the timing gap**: write-time three-test gate in
    step 3, then a critique loop — spawn the critic on the full diff, auto-apply
    every non-KEEP verdict, re-critique once to confirm; report carries the delta
    (N deleted · M trimmed · K rewritten). Philosophy gains "plain words over
    clever words".
  - **@pre-commit-review** spawns the critic on the standalone/PR path whenever
    the diff contains comments; verdicts land as 🟡 Readability Debt, advisory.

### Changed

- **`Task` → `Agent` tool rename** across all skill and command frontmatter and
  prose: Claude Code renamed the subagent-spawning tool in v2.1.63; `Task` still
  works as a backward-compat alias, but the plugin now uses the canonical name.

## [2.7.0] - 2026-07-20

### Changed

- **Tiered godoc budget — R9's comment policy now has hard numbers.** Generated
  godoc comments were verbose enough to slow human review; "menus, not forms" was
  guidance without a bound. R9's rung-1 comment policy is now a **1–5 prose-line
  budget scaled by the symbol's role**: helpers 0–1 line, contract types (parsing
  constructors, self-validating types) 2–3, crossroads (entry points, orchestrators,
  feature front doors) up to 5. Blank `//` lines, the `See docs/<feature>.md` edge,
  and short inline examples (2–4 lines) are free; overflow moves to the feature
  doc — the placement rule made operational at write time. Two bounded escape
  hatches: a package that genuinely earns more moves its godoc to a dedicated
  `doc.go` (~20–30 lines), and a crossroads that deserves richer inline godoc gets
  an optional **expand recommendation** in @documentation's FEATURE report instead
  of extra lines — a human decides. Guidance-only: falsifying questions, hunters,
  and the skeptic are unchanged.
  - `@documentation` FEATURE step 3 applies the budget; its report format gains an
    optional `Expand recommendations` section.
  - reference.md godoc menus annotated with tier budgets; new `doc.go` hatch note,
    checklist budget items, and an over-budget → trimmed-to-tier worked example.
  - Root `coding_rules.md` Comments section aligned with the budget.

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
