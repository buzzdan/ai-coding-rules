---
name: linter-driven-development
description: |
  META ORCHESTRATOR for any Python code change that should end in a commit (features, bug fixes, refactors).
  WHEN: User requests Python code work (implement, fix, add, refactor), mentions "@ldd"/"ldd", or runs a /py-ldd-* command in a Python project.
  Runs the five-phase workflow (PREPARE is an autonomous sub-phase, 1.5): DESIGN → PREPARE → IMPLEMENT (per-behavior TDD loop) → FULL LINT (lint-fixer agent) → REVIEW (per slice) → SHIP.
allowed-tools:
  - Skill(python-linter-driven-development:code-designing)
  - Skill(python-linter-driven-development:testing)
  - Skill(python-linter-driven-development:refactoring)
  - Skill(python-linter-driven-development:pre-commit-review)
  - Skill(python-linter-driven-development:documentation)
  - Agent
---

<objective>
Top-level protocol for Python implementation work: five phases plus the autonomous
PREPARE sub-phase (1.5), where Phase 2 is a per-behavior TDD loop. Rule knowledge lives once in `../../rules/` — this skill never
restates it; it sequences the thin skills (which dispatch into the rules) and the
`python-linter-driven-development:lint-fixer` agent, at the cadence each check's economics demand.
</objective>

<triggers>
- User requests Python code work (implement, fix, add, refactor, update, change) and the
  project is Python (`pyproject.toml` or `.py` files present)
- User mentions "ldd" or "@ldd"
- A `/py-ldd-*` command invokes this skill
On trigger, announce: **"Using py-ldd workflow for this Python code work"** and run pre-flight.
</triggers>

<skill_invocation>
"Invoke @skill-name" means: call the **Skill tool**. Never just mention the skill,
never read its file directly.

| Notation | Skill Tool Call |
|----------|-----------------|
| @code-designing | `Skill(python-linter-driven-development:code-designing)` |
| @testing | `Skill(python-linter-driven-development:testing)` |
| @refactoring | `Skill(python-linter-driven-development:refactoring)` |
| @pre-commit-review | `Skill(python-linter-driven-development:pre-commit-review)` |
| @documentation | `Skill(python-linter-driven-development:documentation)` |

The `python-linter-driven-development:lint-fixer` agent is spawned with the **Agent tool**:
`subagent_type: "python-linter-driven-development:lint-fixer"`. This skill spawns two agents and no others:
the lint-fixer here, and the over-abstraction skeptic in PREPARE gate 4. The review
agents belong to the skills that own them — @pre-commit-review's hunters, skeptic and
critic, @refactoring's comment critic. Refactoring itself is a skill invoked in this
thread, never handed to a general-purpose or any other subagent, however many
escalations there are: a subagent applying refactorings runs unbounded in a context
nobody reads, and is the single most expensive thing this workflow can do.
</skill_invocation>

<flow>
```
1 DESIGN   @code-designing → DESIGN PLAN → user OK
1.5 PREPARE   survey plan's touch points → four gates decide autonomously →
     (@refactoring, preparatory mode) → prep commit(s) · PREPARATION LOG (record, no stop)
2 IMPLEMENT — per behavior:
     ┌─> RED      one failing test, lowest rung        (@testing)
     │            test resists? → prep signal → @refactoring (preparatory) → re-enter RED
     │   GREEN    minimum code to pass — no design work
     │   REFACTOR pkg-scoped lint + rule greps; hits → (@refactoring)
     └── next behavior until all done
3 FULL LINT   ONE run via `python-linter-driven-development:lint-fixer` agent (Agent tool)
     mechanical → FIXED · design → ESCALATED → back to 2's REFACTOR
4 REVIEW   per completed slice: @pre-commit-review → fix → INCREMENTAL re-run
5 SHIP     @documentation → commit (tests and lint green, tree dirty) → ship summary

Refactor-only request (no new behavior): 1.5 via @refactoring → 3 → 4 → 5
```
</flow>

<pre_flight>
1. **Verify Python project**: `pyproject.toml` (or `setup.cfg`/`setup.py`) in root or
   parent directories; note the version `requires-python` pins — `match`, `StrEnum`,
   `asyncio.TaskGroup` and `queue.shutdown()` each have a floor.
2. **Discover commands** (README.md, CLAUDE.md, Makefile, Taskfile.yaml, the `[tool.*]`
   tables in `pyproject.toml`, `tox.ini`/`noxfile.py`, the CI workflow, in that
   order): test + lint commands, and which checkers the repository runs — ruff alone,
   ruff plus mypy, or pyright/flake8/pylint. Fallbacks: `pytest`,
   `ruff check --fix . && ruff format .`; add `mypy` only when a `[tool.mypy]` table or
   `mypy.ini` exists. Never bring a checker the repository does not configure.
3. **List the behaviors** this change delivers — each becomes one Phase 2 TDD cycle.
   No plan or unclear scope → Phase 1 produces the plan; unclear intent → ask.
4. **A request that delivers no behavior is a refactor**, and this skill never
   reshapes code by hand. "Fix the design of", "make X readable", "remove the
   global", "drop the nolint": zero Phase 2 cycles. Route it as Phase 1.5 in its own
   right — the survey runs over the files the request names, the MULTIPLY gate reads
   "the request itself names the violation", and every move is applied by invoking
   @refactoring, which owns the moves, the six-step stopping criteria and the
   commit of each green step. Then Phases 3, 4 and 5 as for any slice. Editing the
   code inline from this skill skips the stopping criteria, which is how a green
   linter ends up shipping with the second global still in place.
</pre_flight>

<phase_1_design>
Invoke @code-designing. It runs the architecture scan, scores candidate domain types,
records an R4 placement decision for every helper/type, and presents a DESIGN PLAN
for user OK. **Do not start Phase 2 until the user approves the plan** — the RED
tests target this designed public API, which is how the design reaches GREEN.
</phase_1_design>

<phase_1_5_prepare>
Preparatory refactoring (Fowler: "make the change easy, then make the easy change"):
reshape what the approved plan is about to touch, BEFORE the first RED, so the
feature lands as add-only. Runs **autonomously** — the four gates below decide;
this phase never asks the user.

**Survey**: for each file/package the DESIGN PLAN touches (integration points,
functions it extends, packages receiving new code), run the rule detection greps from
the `../../rules/R*.md` Falsifying questions, scoped to those files only. Same
commands as the REFACTOR step, different premise: this code is probably lint-green
and can still be hostile to the plan.

**Four gates per finding — all mechanical, no user questions:**

1. **MULTIPLY** — would landing the plan add an instance of this violation or force a
   workaround (a new case in an already-duplicated switch, R11; new behavior on a raw
   primitive, R1; a new step in an at-limit function, R3; new code testable only by
   mutating a global, R8)? No → not preparation; leave it for Phase 4's advisory
   report.
2. **SAFE** — are the paths to reshape covered (the coverage report for the touched
   packages)? Uncovered → write characterization tests through the public API first
   (@testing); they are the move's safety net and keep their value after. When the
   missing test seam IS the finding (globals block testing), the prep move creates
   the seam — R8's Extract Clean Island exists for exactly this.
3. **BOUNDED** — effort S/M (hunter scale) → proceed. L → defer to Phase 4's report
   as `PREP-DEFERRED`, UNLESS gate 2 showed the feature cannot be tested at all
   without it — then it is not preparation but a design-plan gap: return to Phase 1.
4. **SKEPTICIZED** — any prep move that creates a type/interface/package is judged by
   the `python-linter-driven-development:overabstraction-skeptic` (Agent tool; spawn prompt per @pre-commit-review step 3), with
   one sharpening in the spawn prompt: the justification is the approved plan in
   hand, not an imagined future — score the extraction as if the feature already
   existed. REFUTED → apply the cheaper alternative or defer. R2's construction
   mechanics — a validating constructor, underscore-prefixed fields, an options type and its
   `With*` functions, a named Null Object default — are not extractions and skip this
   gate: apply R2 as written.

**Apply** the survivors via @refactoring (`<preparatory_mode>`); full test suite and
lint green after every move; land the prep work as its own commit(s) before the first
RED — the Two Hats at commit granularity, and the reviewer sees reshaping and feature
separately.

**Emit a PREPARATION LOG** — a record, not a question; the loop continues:

```
PREPARATION LOG
Touch points surveyed: [files] · findings: N
Applied: [rule → move → commit] (gates: multiply ✓ safe ✓ bounded ✓ skeptic ✓/n-a)
Deferred to Phase 4: [finding — failed gate]
Feature landing shape after prep: [add-only / near-add-only / unchanged]
```

Zero findings passing the gates is the common case — say so in one line and move on.

Inverse trap: reshaping files the plan does not touch is litter-pickup wearing prep's
clothes — a different activity on a different budget; pre-building abstractions this
plan does not need is speculative generality — gate 4 exists to kill it.
</phase_1_5_prepare>

<phase_2_implement>
One TDD cycle per behavior:

**RED** — write ONE failing test for the behavior. Place it by the composition
ladder — the lowest rung that contains the behavior (@testing,
`<composition_ladder>`). Run it; confirm it fails for the right reason.

If the test *resists* — fixture surgery, mutating globals to reach the behavior,
driving three layers to observe one seam — do not force it: that friction is a prep
signal Phase 1.5's survey missed. Suspend the cycle, route the friction through the
same four PREPARE gates, apply via @refactoring (`<preparatory_mode>`), land the prep
commit, re-enter RED. Autonomous, like Phase 1.5 — no user question.

**GREEN** — minimum code to pass. Explicitly allowed to be ugly; no design polish in
this step. **Never invoke @code-designing from GREEN**: the design already happened
in Phase 1 and reaches GREEN through the RED test's shape. If GREEN reveals the
design is wrong (a type doesn't fit, a hidden concept emerges): finish the cycle,
then route through REFACTOR → @refactoring → its escalation to @code-designing.
Design revision is a deliberate checkpoint, never a mid-GREEN detour.

**REFACTOR (linter-driven)** — on the code just written:
1. Package-scoped lint (fast): `ruff check <pkg>/` plus `mypy <pkg>/` where the
   repository configures mypy
2. Cheap rule greps: run the detection commands from the **Falsifying questions**
   sections of the `../../rules/R*.md` files relevant to what was written.
Any hit → invoke @refactoring: its `<routing_table>` routes each failure to the
owning rule's Fix pattern. The linter says WHAT to refactor; the rules say HOW.
Fix now — these findings are mechanical and local: cheapest at this moment,
compounding if deferred.

Loop to the next behavior until all behaviors are done.
</phase_2_implement>

<phase_3_full_lint>
Delegate ONE lint run to the `python-linter-driven-development:lint-fixer` agent (Agent tool, isolated context — the
fix loop's token noise stays out of this conversation). Its scope is the workflow's:
the whole repository for a feature slice, where the full run catches what
package-scoped runs cannot (cross-package issues, whole-file and whole-package rules
such as file-length-limit and package-size zones); the packages a caller resolved when
the entry was a scoped command (`/py-ldd-quickfix` names the rung and the files).
Name the scope in the agent's spawn prompt; it lints nothing wider.

The agent returns `FIXED` (mechanical — done) and `ESCALATED` (design-level, each
with a rule route from its embedded routing table). An `ESCALATED: … → mechanical,
budget spent` line is mechanical work the agent's budget did not reach, not design:
spawn the lint-fixer again, fresh, over the packages it names — at most three times
per scope, and never after a fresh lint-fixer reports `FIXED: none` over the same
packages. What is left at that cutoff, and every `mechanical, no progress` line, is
unresolved mechanical lint with no rule route: Phase 3 stops there, and the ship
summary lists each `file:line` under `LINT STATUS: escalations pending` — never handed
to @refactoring, which has no rule for it, never to a subagent. Route every design
escalation back through the Phase 2 REFACTOR step — invoke @refactoring, in this
thread, with the routes; **never auto-redesign here, and never delegate the
escalations to a subagent** (`<skill_invocation>`). Package-size escalations follow
`<package_decomposition>` in @refactoring's `reference.md`
(`sed -n '/^<package_decomposition>/,/^<\/package_decomposition>/p; /^### Package decomposition/,$p'`; decomposition
lands in its own commit). Repeat Phase 3 until the agent reports `LINT STATUS: green`,
or until the respawn ceiling ends it with that list.
</phase_3_full_lint>

<phase_4_review>
Per completed vertical slice (multi-slice work reviews each slice as it completes),
invoke @pre-commit-review — it orchestrates parallel rule hunters plus the
over-abstraction skeptic; it spawns agents and reports, **never edits**.

NOT mid-implementation (its `<timing>` contract): GREEN-step code is supposed to
look under-designed, so reviewing it produces false positives — and the hunters'
fresh-context value only pays on finished work. The REFACTOR-step greps are the
mid-implementation net; this pass is the verification net.

Findings return categorized (Bugs / Design Debt / Readability Debt / Polish), all
advisory. Fix bugs and user-accepted findings via @refactoring — except accepted R9
(documentation-network) findings, whose fixer is @documentation — then re-invoke
@pre-commit-review in INCREMENTAL mode until the delta reports clean.

**Cluster routing**: report entries marked 🔗 CLUSTER (≥2 hunters converging on one
anchor) are fixed design-first, never member-by-member — partial fixes undo each
other (R1 names an enum that R11's move then replaces; R2 places validation that
R11's move relocates). Invoke @code-designing in cluster-scoped mode (it skips the
architecture scan and the user-OK gate — acceptance was inherited when the cluster's
findings were accepted; output is a mini DESIGN PLAN for the one concept the cluster
names), then @refactoring implements that plan; the member findings resolve as
consequences of one design. Singleton findings route directly to @refactoring as
before.
</phase_4_review>

<phase_5_ship>
1. Invoke @documentation (FEATURE mode): docstring + feature docs, wired into the
   documentation network (index line, edges both directions, root import), plus its
   R9 self-check over the diff and its comment-critic critique loop (the critic
   reviews every comment in the diff against R9's three-test standard;
   @documentation applies the verdicts and re-critiques once — R3 routes from the
   critic go back through @refactoring like any R3 finding).
2. Commit. When tests (`pytest`) and lint (Phase 3) are green and the tree
   is dirty, commit the slice with the ship summary as the message. A green slice left
   uncommitted "for the user" is the one state this workflow never ends in: the user
   can amend, split or revert a commit; an uncommitted tree evaporates with the
   session. Prep commits (Phase 1.5) stay separate.
3. Present the ship summary: the commit hash, tests green, lint green, review delta
   (Phase 4), files changed, and — when @refactoring ran in this session — its
   `Stop check` block verbatim: the six labelled lines (`1 gates` … `6 commit`), not
   a prose account of them. The block is a precondition of the summary, not an
   ornament: no block, or fewer than six lines, means the refactoring did not finish —
   run its `<stopping_criteria>` now, render the block, then present. User decides
   only about the deferred advisory findings: fix them now or later.
</phase_5_ship>

<success_criteria>
- [ ] Design plan user-approved before the first RED
- [ ] PREPARE ran its survey over the plan's touch points; every applied prep move
      passed all four gates and landed in its own commit; PREPARATION LOG emitted
- [ ] Every behavior completed a RED → GREEN → REFACTOR cycle
- [ ] Package-scoped lint + rule greps clean after each cycle
- [ ] lint-fixer reported `LINT STATUS: green`; all escalations resolved via @refactoring
- [ ] @pre-commit-review INCREMENTAL delta clean, or findings explicitly deferred by user
- [ ] @documentation (FEATURE mode) done — docs wired into the network, R9 self-check
      clean, comment-critic critique loop applied and confirmed clean (or remainder
      reported); the green slice committed and the ship summary presented with its
      hash, deferred advisory findings listed
</success_criteria>
