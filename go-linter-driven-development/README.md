# Go Linter-Driven Development

**Stop fighting your linter. Let it guide you to better code.**

This Claude Code plugin turns Go development into a smooth, test-first workflow where quality gates don't slow you down — they guide your design. Instead of manually running tests, fixing linter errors one by one, and wondering if your design is solid, the plugin sequences design, TDD, linting, and an evidence-based design review at the cadence each check's economics demand.

### The Problem It Solves

You've been there: write some code, run tests (they pass!), run the linter... 15 errors. Fix those. Run again. More errors. Fix complexity here, function length there. Finally get it green — but is the design actually good?

The linter tells you **WHAT** to change (complexity 18, function too long). This plugin's rules tell you **HOW** — each linter failure routes to the one rule whose fix pattern owns the repair. And the checks a linter *can't* run — primitive obsession, mixed abstraction levels, test-only interfaces — are hunted by fresh-context review agents against your actual diff.

## Architecture: Rules as Data

The organising idea of v2: **the rule is the unit, not the phase.** Each design principle lives exactly **once**, as data, in `rules/`. Everything else is a thin view over those rules or an agent that receives a rule as a payload.

```
go-linter-driven-development/
├── maxims.md     the uncompiled layer — named design questions above the rules
├── rules/        R1-primitive-obsession … R12-mutation-discipline   (single source of truth)
├── examples/     storify-leaf-type · overabstraction-cidr · dependency-rejection ·
│                 anti-if-dispatch · switch-to-polymorphism   (case law)
├── skills/       linter-driven-development · code-designing · refactoring ·
│                 pre-commit-review · testing · documentation   (thin directional views)
├── agents/       rule-hunter · overabstraction-skeptic · lint-fixer   (isolated workers)
├── commands/     go-ldd-analyze · autopilot · quickfix · prepare · review · status · wire-repo-brain
└── hooks/        package-size gate
```

**Five layers, one fact per fact:**

- **[`maxims.md`](maxims.md)** — the layer above the rules: named design maxims ("Tell, don't ask", "Duplication is far cheaper than the wrong abstraction", "Make the change easy…") as *questions*, each pointing at the rules that compile it. Maxims live only at the judgment points — design interrogation (@code-designing), escalation vocabulary (@refactoring), the skeptic's doctrine — and are banned from hunters: **maxims propose, evidence disposes.** A maxim that keeps convicting graduates into a rule.
- **[`rules/`](rules/)** — R1–R12, each a self-contained hunter payload. A rule file states its Principle, Why, a real-world canonical before/after, Design guidance (forward), a Fix pattern (backward), and Falsifying questions (each phrased to *disprove* compliance, with a grep/count detection command). A rule's content is normative in its file and nowhere else — everything else points at it.
- **[`examples/`](examples/)** — deep worked case studies (full before/after code + the reasoning). Rules cite them by relative path instead of inlining long studies.
- **[`skills/`](skills/)** — thin directional views (~100–150 lines) that *sequence* and *route* into the rules. They never restate rule content.
- **[`agents/`](agents/)** — read-only or mechanical workers spawned in isolated contexts. **Agents get knowledge as spawn-time payload — the relevant rule file's content is pasted into the prompt. Agents do NOT invoke skills.**

### The Five-Phase Flow

The [`@linter-driven-development`](skills/linter-driven-development/SKILL.md) skill is the meta-orchestrator. It sequences the thin skills and the `lint-fixer` agent at the cadence each check's economics demand:

```
1 DESIGN     @code-designing → DESIGN PLAN → user OK
1.5 PREPARE  preparatory refactoring (Fowler): survey the plan's touch points,
      four autonomous gates decide, @refactoring reshapes → prep commit(s), no user stop
2 IMPLEMENT  per behavior:
      ┌─> RED      one failing test, lowest rung on the composition ladder   (@testing)
      │            test resists? → late prep signal → same gates → prep commit → re-enter
      │   GREEN    minimum code to pass — no design work
      │   REFACTOR package-scoped lint + rule greps; any hit → @refactoring
      └── next behavior until all done
3 FULL LINT  ONE full-repo run via the lint-fixer agent (isolated context)
      mechanical → FIXED · design → ESCALATED → back to Phase 2's REFACTOR (@refactoring)
4 REVIEW     per completed slice: @pre-commit-review spawns hunters + skeptic → advisory report
5 SHIP       @documentation → commit summary → user commits
```

Design happens once, up front (Phase 1); the RED test's shape carries that design into GREEN. PREPARE makes the change easy before making the easy change — reshaping only what the plan touches and only violations the plan would multiply, gated autonomously (the over-abstraction skeptic judges any extraction) so autopilot never stops to ask. The cheap per-cycle greps in Phase 2's REFACTOR are the mid-implementation net; the Phase 4 hunter/skeptic pass is the verification net on finished work.

### The Hunter / Skeptic Review Model

Phase 4 ([`@pre-commit-review`](skills/pre-commit-review/SKILL.md)) is pure orchestration — it spawns agents and reports, but **never edits code and never blocks a commit**:

1. **Grep pre-filter** (in-context, cheap): run each rule's detection commands against the diff. A rule with zero hits gets no hunter.
2. **Parallel hunters**: for every rule with hits, spawn one [`rule-hunter`](agents/rule-hunter.md) — single obsession, single rule file pasted in full as its entire rulebook. Each returns evidence-backed findings (`rule | file:line | falsifying-question answers | fix pattern | effort`).
3. **Skeptic pass**: every "create a type/package" proposal goes to one [`overabstraction-skeptic`](agents/overabstraction-skeptic.md), which tries to *kill* each extraction using R1's juiciness scorecard and the CIDR case file. A refuted proposal ships only its cheaper alternative (better naming, private fields + accessors).
4. **Merged report**: surviving findings categorized as 🐛 Bugs / 🔴 Design Debt / 🟡 Readability Debt / 🟢 Polish. All advisory — the caller decides what to fix. Findings from *different* rules converging on one anchor (the same type, field, or function) are additionally reported as a 🔗 **CLUSTER** — each hunter is blind to the others, so independent convergence is evidence of a missing domain concept, and the cluster routes design-first (`@code-designing` scoped to the concept, then `@refactoring` implements) instead of being fixed member-by-member.

Isolated contexts matter: the `lint-fixer` loop's token noise stays out of your conversation, and each hunter's fresh context is exactly what makes its findings trustworthy on finished work.

## Link Map

**Rules → file** (single source of truth):

| Rule | File | Enforces |
|------|------|----------|
| R1 | [`rules/R1-primitive-obsession.md`](rules/R1-primitive-obsession.md) | Domain concepts as types, not raw primitives (incl. juiciness scoring) |
| R2 | [`rules/R2-self-validating-types.md`](rules/R2-self-validating-types.md) | Validate in the constructor; no invalid states, nil not a value |
| R3 | [`rules/R3-storifying.md`](rules/R3-storifying.md) | One abstraction level per function; extract named steps |
| R4 | [`rules/R4-helper-placement.md`](rules/R4-helper-placement.md) | Helper visibility/placement on the placement ladder |
| R5 | [`rules/R5-vertical-slice.md`](rules/R5-vertical-slice.md) | Group by feature, not layer; file-per-type |
| R6 | [`rules/R6-test-only-interfaces.md`](rules/R6-test-only-interfaces.md) | No interface whose only second implementer is a test double |
| R7 | [`rules/R7-test-placement.md`](rules/R7-test-placement.md) | `pkg_test` only, no wantErr conditionals, right-rung tests, no sleeps |
| R8 | [`rules/R8-no-globals.md`](rules/R8-no-globals.md) | No package-level state; no `context.Background()` in library code |
| R9 | [`rules/R9-repo-brain.md`](rules/R9-repo-brain.md) | Documentation network: fact at its lowest rung, reachable from the root, edges both directions; index wired into CLAUDE.md |
| R10 | [`rules/R10-concurrency-safety.md`](rules/R10-concurrency-safety.md) | Goroutines with owners and exit paths; shared state guarded where it lives; no production sleeps |
| R11 | [`rules/R11-conditional-dispatch.md`](rules/R11-conditional-dispatch.md) | One dispatch owner per kind/variant family (Anti-IF): duplicated kind-switches become interface/map dispatch chosen once at the boundary; a single switch stays and goes exhaustive |
| R12 | [`rules/R12-mutation-discipline.md`](rules/R12-mutation-discipline.md) | Mutation only through invariant-owning methods: constructors copy collections in, queries copy (or iterate) out, no query/modifier hybrids, no setters around validating constructors |

**Examples → rules demonstrated** (case law):

| Example | Demonstrates |
|---------|--------------|
| [`examples/storify-leaf-type.md`](examples/storify-leaf-type.md) | R3, R1, R2 — storifying a fat function; extracting a self-validating leaf type |
| [`examples/overabstraction-cidr.md`](examples/overabstraction-cidr.md) | R1 — when an extraction is over-abstraction (the skeptic's payload) |
| [`examples/dependency-rejection.md`](examples/dependency-rejection.md) | R8 — dependency rejection: eliminating globals by threading dependencies |
| [`examples/anti-if-dispatch.md`](examples/anti-if-dispatch.md) | R11 — duplicated kind-switch → interface dispatch / strategy map, plus the kept-switch rejection (the skeptic's dispatch payload) |
| [`examples/switch-to-polymorphism.md`](examples/switch-to-polymorphism.md) | R11, R6 — type switch over an owned interface → fill-style method; the earned/sealed interface; the dependency-direction rejection |

**Skills → role** (thin views):

| Skill | Role |
|-------|------|
| [`@linter-driven-development`](skills/linter-driven-development/SKILL.md) | Meta-orchestrator — sequences the five phases (plus the autonomous PREPARE sub-phase, 1.5) |
| [`@code-designing`](skills/code-designing/SKILL.md) | FORWARD view — which rule to open at each design step (Phase 1) |
| [`@refactoring`](skills/refactoring/SKILL.md) | BACKWARD view — routes each linter/review failure to its owning rule's Fix pattern; preparatory mode reshapes ahead of a planned change (Phase 1.5) |
| [`@pre-commit-review`](skills/pre-commit-review/SKILL.md) | Orchestrates the hunter/skeptic review (Phase 4); reports, never edits |
| [`@testing`](skills/testing/SKILL.md) | The composition ladder — test each behavior at the lowest rung that contains it |
| [`@documentation`](skills/documentation/SKILL.md) | Repo-brain author (R9) — behavior docs + network wiring; FEATURE mode (Phase 5) / BOOTSTRAP mode |

**Agents → spawned by** (payload-fed, isolated):

| Agent | Spawned by | Gets as payload | Edits? |
|-------|-----------|-----------------|--------|
| [`rule-hunter`](agents/rule-hunter.md) | `@pre-commit-review` (one per rule with hits, in parallel) | ONE full `rules/R*.md` file + diff scope | No (read-only) |
| [`overabstraction-skeptic`](agents/overabstraction-skeptic.md) | `@pre-commit-review` (after hunters report) | R1 juiciness scorecard + `examples/overabstraction-cidr.md` | No (read-only) |
| [`lint-fixer`](agents/lint-fixer.md) | `@linter-driven-development` (Phase 3) | routing table (linter failure → rule) | Yes (mechanical only; escalates design) |

## Slash Commands

| Command | Purpose | Auto-Fix | File targeting |
|---------|---------|----------|----------------|
| [`/go-ldd-autopilot`](commands/go-ldd-autopilot.md) | Full workflow (Phases 1–5) | ✅ Yes | — |
| [`/go-ldd-quickfix [files]`](commands/go-ldd-quickfix.md) | Quality-gates loop until green (code exists) | ✅ Yes | ✅ Optional |
| [`/go-ldd-prepare <change> [files]`](commands/go-ldd-prepare.md) | Preparatory refactoring: reshape what a planned change touches, so it lands add-only | ✅ Yes | ✅ Optional |
| [`/go-ldd-analyze [files]`](commands/go-ldd-analyze.md) | 🔍 Tests + lint + review, combined report | ❌ No | ✅ Optional |
| [`/go-ldd-review [files]`](commands/go-ldd-review.md) | 🔍 Commit-readiness check | ❌ No | ✅ Optional |
| [`/go-ldd-status`](commands/go-ldd-status.md) | Show current phase + progress | N/A | — |
| [`/wire-repo-brain [path]`](commands/wire-repo-brain.md) | Wire the documentation network in one pass: upward edges → docs → index.md → CLAUDE.md (@documentation BOOTSTRAP) | ✅ Wiring only | ✅ Optional |

## How Auto-Detection Works

When you request Go code work (e.g., "implement feature X", "fix bug in handler.go"), Claude detects that the linter-driven-development skill applies and **asks for permission**:

```
Use skill "go-linter-driven-development:linter-driven-development"?
Claude may use instructions, code, or files from this Skill.

Do you want to proceed?
❯ 1. Yes
  2. Yes, and don't ask again for this skill in [current-directory]
  3. No, and tell Claude what to do differently
```

**Recommended:** Select option 2 on first use — the skill then runs automatically in that directory.

**Triggers auto-detection:**
- Action verbs: `implement`, `fix`, `build`, `add`, `refactor`, `update`, `change`, `modify`
- Working in a Go project (detects `go.mod` or `.go` files)
- Mentions "ldd" or "@ldd"

On trigger, the skill announces **"Using go-ldd workflow for this Go code work"** and runs pre-flight.

## Why Linter-Driven Development?

### Code Written for Understanding, Not Just Execution

The philosophy: **if code takes more than 10–15 seconds to understand, it's too complex.**

Modern development involves two readers:
- **Humans** — limited by working memory (4–7 items, Miller's Law)
- **AI** — works on heuristics from clean, well-documented code

Clean, storified code with clear abstractions gives both lower cognitive load and better heuristics.

### The Three Pillars of Maintainability

Linter rules enforce objective quality standards:

**1. Cyclomatic Complexity ≤ 10** — independent execution paths; higher = more places for bugs to hide.
**2. Cognitive Complexity ≤ 15** — human effort to understand; penalizes nesting and mixed abstractions.
**3. High Maintainability Index** — composite metric predicting long-term code health.

### How Linter Rules Drive Design

Each linter failure has an owning rule with a fix pattern — the mapping is [`@refactoring`](skills/refactoring/SKILL.md)'s routing table; the design-decision linters (`argument-limit`, `function-result-limit`) route via [`@code-designing`](skills/code-designing/SKILL.md):

**`gochecknoglobals`** → R8: dependency injection instead of global state
**`gocognit` / `gocyclo`** → R3: extract named steps, reduce nesting
**`funlen`** → R3: functions < 50 LOC, single responsibility
**`argument-limit` / `function-result-limit`** → R1: options/result types
**`file-length-limit` / package-size zones** → R5: file-per-type, sub-packages

Design decisions aren't subjective — they're driven by measurable quality metrics, and each metric routes to a named fix.

## Installation

**Step 1: Add the marketplace**
```
/plugin marketplace add buzzdan/ai-coding-rules
```

**Step 2: Install the plugin**
```
/plugin install go-linter-driven-development@ai-coding-rules
```

**Verify installation:**
```
/plugin list
```
Should show: `go-linter-driven-development (enabled)`

## Quick Start

**Zero configuration required.** The plugin discovers your project's test and lint commands from `README.md`, `CLAUDE.md`, `Makefile`, or `Taskfile.yaml`. Just install and go.

### The Easiest Way: Just Talk to It

Tell Claude what you want:

```
"implement step 1"
"ready to start coding"
"do the next task"
"execute the authentication feature"
```

The plugin recognizes these phrases and **automatically engages the five-phase workflow**. You don't need to remember commands.

### Want More Control? Use Slash Commands

```bash
# Starting fresh? Full workflow (5-15 min)
/go-ldd-autopilot

# Code is written, just needs to pass linter/tests? (2-5 min)
/go-ldd-quickfix

# Want to see what's wrong before deciding whether to fix? (read-only)
/go-ldd-analyze

# About to commit, want one final check? (read-only)
/go-ldd-review

# Lost track of where we are?
/go-ldd-status
```

**File targeting:** commands marked `[files]` accept an optional pattern to scope the run:

```bash
/go-ldd-analyze ./pkg/parser/
/go-ldd-quickfix ./pkg/handler.go
/go-ldd-review ./cmd/main.go
```

### Need Just One Piece? Use Individual Skills

Skills are expert consultants you can call on demand:

```
"Use @code-designing to plan types for payment processing"
"Use @testing to structure tests for UserService"
"Use @refactoring to reduce complexity in HandleRequest"
"Use @pre-commit-review to validate this code"
"Use @documentation to document the auth feature"
```

## How the Plugin Categorizes Issues

The [`@pre-commit-review`](skills/pre-commit-review/SKILL.md) report groups findings by urgency — all advisory, none block a commit:

- 🐛 **Bugs** — fail at runtime regardless of rule (fix immediately)
- 🔴 **Design Debt** — R1, R2, R4, R5, R6, R7, R8, R11, R12 (fix before commit recommended)
- 🟡 **Readability Debt** — R3, R9, unclear naming (improves maintainability)
- 🟢 **Polish** — minor idiomatic improvements, the skeptic's cheaper alternatives

Every finding carries evidence (`file:line` + the falsifying-question answer or command output) and cites its rule's Fix pattern for HOW to fix.

## The Design Principles Behind This

The plugin follows opinionated Go best practices, each with an owning rule:

**Design:** no primitive obsession (R1), self-validating types (R2), vertical slices (R5), no globals (R8), owned goroutines and guarded shared state (R10), one dispatch owner per variant family — the Anti-IF rule (R11), closed mutation surfaces — no leaked aliases or unvalidated setters (R12).
**Testing:** test the public API via `pkg_test` (R7), the composition ladder over the pyramid, real in-memory dependencies over mocks, no test-only interfaces (R6).
**Refactoring:** storify top-level functions (R3), helpers on the placement ladder (R4), let the linter say WHAT and the rules say HOW.
**Documentation:** a networked repo brain — each fact at its lowest rung, reachable from the root, edges pointing both ways (R9).

## v2 Changes

Earlier versions organised knowledge by *phase* and centralised analysis in two generalist agents: **`quality-analyzer`** (a parallel tests+linter+review orchestrator) and **`go-code-reviewer`** (a single design reviewer that loaded the review skill for guidance). v2 replaces both:

- Knowledge moved out of the skills and into `rules/` as data — stated once, cited everywhere.
- The single design reviewer became **parallel single-obsession `rule-hunter` agents** plus the **`overabstraction-skeptic`**, each fed the relevant rule file as a spawn-time payload rather than loading a skill.
- The lint loop moved into the isolated **`lint-fixer`** agent.

If you have muscle memory for `quality-analyzer` or `go-code-reviewer`, the closest v2 entry points are `/go-ldd-analyze` (read-only combined report) and `@pre-commit-review` (the hunter/skeptic review).

## Updating

```
/plugin update go-linter-driven-development@ai-coding-rules
```

See [CHANGELOG.md](CHANGELOG.md) for what changed between versions — including the v2.0.0 breaking changes and migration notes.

## Uninstalling

```
/plugin
```
Select "go-linter-driven-development" and choose "Uninstall".

## Need Help or Want to Contribute?

**Documentation:** Full details in the [main repository](https://github.com/buzzdan/ai-coding-rules)

**Found a bug or have an idea?** [Open an issue](https://github.com/buzzdan/ai-coding-rules/issues)

**Want to contribute?** PRs welcome — typos, examples, or improvements to the rules and skills.

## License

MIT — Use it however you want!

---

**Happy coding!** May your linter always be green and your complexity always be low. 🚀
