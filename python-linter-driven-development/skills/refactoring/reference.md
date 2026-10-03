# Refactoring — Reference

`SKILL.md` holds the loop and the exit; this file holds what a step reads by `sed`
range when it needs it, never the file whole: the pattern index (which rule owns each
move), file and package routing, preparatory mode, the stopping criteria in full, who
invokes what, and the multi-rule procedures. Each range is printed inside a Bash call
the skill already makes — the loop's first lint run, the Gates run of the exit — so it
costs no round trip of its own. Single-rule moves live in the rules'
**Fix pattern** sections and are applied from there; deep worked case law is under
`../../examples/`.

## Pattern index

Each named refactoring move is owned by one rule's **Fix pattern** section — apply it
from there, never from memory:

| Move | Owner |
|------|-------|
| Extract Function (named after the comment), Early Returns, Honest Rename, Extract Leaf Type | `../../rules/R3-storifying.md` |
| Replace Primitive with Domain Type, Extract Collection Type, Replace Sentinel with Declared Absence, Name enum strings, Over-abstraction rejection | `../../rules/R1-primitive-obsession.md` |
| Add validating constructor, Hoist method checks, Delete re-validation, Separate Failure from Absence, Introduce Null Object (optional collaborator) | `../../rules/R2-self-validating-types.md` |
| Demote helper (rung 1), Promote to feature/domain package (rungs 2–3), Split policy from vocabulary | `../../rules/R4-helper-placement.md` |
| Slice out a feature, Rename layer files by role, Split a generic package by owner | `../../rules/R5-vertical-slice.md` |
| Delete the Test Seam, Rewrite test around real collaborators, Delete the double | `../../rules/R6-test-only-interfaces.md` |
| Move test down a rung, Split Success and Error Tables, Kill the surviving mutant, Replace sleep with synchronization | `../../rules/R7-test-placement.md` |
| Extract Clean Island, Push Global Up One Level, Replace Import-Time Initialization with a Constructor, Pass Cancellation Down | `../../rules/R8-no-globals.md` |
| Inject the Exit Path, Make Concurrent Work Joinable, Extract Synchronized Owner, Replace Sleep with Cancellable Wait, Delete Unearned Guards | `../../rules/R10-concurrency-safety.md` |
| Replace Duplicated Switch with Interface Dispatch, Replace If-Chain with Strategy Map, Introduce Null Object, Split Flag Argument, Keep the Single Exhaustive Switch | `../../rules/R11-conditional-dispatch.md` |
| Copy on the Way In, Copy on the Way Out / Encapsulate Collection, Separate Query from Modifier, Remove Setting Method, Split Variable | `../../rules/R12-mutation-discipline.md` |

**Introduce Null Object, the shape.** The null object is a *named* value of the
collaborator's existing concrete type — a sink composing the standard no-op writer, a
clock that is the real clock — supplied as the constructor's default through an option
or passed by the caller by name. Never a new interface with one no-op implementation
(R6), never a None parameter that means "default" (R2). An option handed None
records the error on the value under construction and the constructor fails with it
(R2's example) — the option never substitutes the default and never stores the
None.

**In Python:** a `NullSink` whose `write()` discards, bound once as a module-level
constant `NULL_SINK = NullSink()` (a name, not a call — ruff `B008` flags a call in
a default), and a clock that is `SYSTEM_CLOCK = SystemClock()` the same way; the
parameter is keyword-only and typed `Sink`, never `Sink | None`, so
`Reporter(sink=None)` fails ty before it runs and `__init__` raises `TypeError`
for the caller ty never saw. A `sink: Sink | None = None` default replaced inside
`__init__` is allowed only when the default is genuinely mutable or expensive to
build; the attribute is then still typed `Sink` and no method guards it.

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
decomposition): "Multi-rule procedures", below.

**Case law** (deep worked studies):
- Storify → leaf type discovery: `../../examples/storify-leaf-type.md`
- Over-abstraction rejection + cheaper alternatives: `../../examples/overabstraction-cidr.md`
- Incremental global elimination: `../../examples/dependency-rejection.md`
- Duplicated kind-switch → interface dispatch (and the kept-switch rejection): `../../examples/anti-if-dispatch.md`
- Type switch over an owned interface → fill-style method (and the dependency-direction rejection): `../../examples/switch-to-polymorphism.md`

## Slices and receipts

A slice is the unit of work this skill hands out: the moves that share a file, in the
order the multi-rule procedures sequence them, over those files. The parent composes
no slice by hand and applies none itself: a parent editing at a context of a hundred
thousand tokens is the most expensive worker there is, and every edit it makes is
re-billed on every later call. It writes a table and runs a script.

**The table.** `slices.tsv`, one line per routed finding or lint escalation, four
tab-separated fields: the rule (`R<n>`); the move as the rule's Fix pattern spells it
(a combined name such as Extract Clean Island + Push the Global Up One Level is two
lines); the files, relative to the repository, space-separated; the finding's anchor,
`file:line`. A lint configuration file in the files is refused — changing lint
configuration is suppression by another route.

**The script.** `bash <this skill dir>/../../scripts/ldd-slices.sh slices.tsv` groups the
lines that share a file into slices (a chain of shared files is one slice, whatever its
size; over five files it is marked `large` and stays whole), orders each slice's moves
by the sequencing keys (`--order` prints them: storify before early returns before
extract function, extract type after, placement moves last, the comment critic's
verdicts after everything), assigns the slices to waves so that no two slices of one
wave touch the same package (two workers in one package would see each other's
half-edits in their test runs), and prints one block per slice under its wave:
`MOVE n:` lines, `FILES:` (one sorted line), `PKGS:`, `RULE:` (one per rule). A move
name that is not the rule's spelling is refused with the valid keys printed.

**The base.** Before the first wave, run `TEST:` once and write down the names of the
tests that fail — `BASE-RED:` — or `none`. A worker judges its move by the delta
against the base commit: a test in `BASE-RED:` is not its failure, a lint line in a
file outside its slice is `OUTSIDE:` and logged, and only what the move itself turned
red defers it.

**The waves.** Spawn every slice of a wave in one message — one
`python-linter-driven-development:move-implementer` per slice, Agent tool, foreground — with the slice's
block and seven lines appended, paths and commands only, never pasted rule text or
source: `BASE:` the current commit; `BASE-RED:`; `TEST:` the project's test command;
`LINT:` the line `bash <scripts>/ldd-attempt.sh --lint-delta <BASE> <the slice's FILES>`
prints — the linter over the slice's changes only; `BUILD:` the project's build
command, or `none`; `WRAPPER:` the absolute path of `scripts/ldd-attempt.sh`;
`REPORT:` a fresh `mktemp -d`. Every test, lint and build run of the worker goes
through that wrapper, which keeps the output under the report path and counts three
runs per move; the plugin's hook denies the worker any such run that does not. Read
the receipts before the next wave — never the tree.

**The receipt** is at most fifteen lines, and its first line decides:
- `STATUS: GREEN` — every move committed, one commit each (`COMMIT:` lines, the
  move's name first in the subject). The hashes go in the `6 commit` line.
- `STATUS: PARTIAL-GREEN` — some moves committed; the rest `DEFERRED`, `DEFERRED-NEEDS`
  or `SKIPPED` (a later move on a deferred move's anchor).
- `STATUS: DEFERRED` — no move committed. The attempt is a patch under `REPORT:`, the
  files are restored. A `DEFERRED-NEEDS: <files>` line names files outside the slice
  the move needed: re-spawn once, in the next wave, with those files appended to the
  slice's line in the table and the script run again; a second `DEFERRED-NEEDS` is
  final. Any other deferral is final at once: the parent does not finish the move by
  hand and does not spawn a third worker on it.
- `STATUS: NEEDS_CONTEXT` — an input did not resolve, or the worker read five times
  without editing. Fix the input the receipt names and spawn once more; a second
  `NEEDS_CONTEXT` is a line in the block.

**The spot-check.** Before the next wave, `git show --name-only <sha>` for every
`COMMIT:` of the wave: a commit that touches a file outside its slice's `FILES:` is a
`Stop check` line (`BROADER CONTEXT`, with the hash and the file), never silently
kept.

**The ledger.** Append one line per slice and status to `<dir>/slices.log` as the
receipts arrive, so a parent whose context was compacted re-dispatches nothing.

**Verdicts and doc fixes are slices.** The comment critic's TRIM / REWRITE / DELETE
verdicts (step 4 of the stopping criteria) and R9's doc fixes are not applied by the
parent: the verdict text goes to `<dir>/verdicts-<n>.txt`, the table gets the line
`R9` · `Apply comment verdicts` · the files · that path, and the script orders that
slice last.

Line `0 slices` of the `Stop check` block counts them: `<k> slices in <w> waves — <n>
GREEN · <n> PARTIAL-GREEN · <n> DEFERRED · <n> NEEDS_CONTEXT · <n> re-spawned · <n>
commits spot-checked`.

## File and package routing

<file_and_package_routing>
**A module over ~450 lines (ruff has no file-length rule — count):**

| File pattern | Action |
|---|---|
| Multiple juicy types | Route to @code-designing — one juicy type per module (juiciness per R1) |
| Single god class (>15 methods) | `reference.md` → god-object decomposition, then @code-designing for the composition |
| Long functions, few types | Storify → extract functions (R3) |

<package_decomposition>
**Package-size zones** — count non-test `.py` modules per package directory:

```
find <dir> -maxdepth 1 -type f -name '*.py' -not -name 'test_*.py' -not -name '*_test.py' -not -name 'conftest.py' -not -name '__init__.py' -not -name '*_pb2.py' -not -name '*_pb2_grpc.py' | wc -l
```

≤7 green — fine. 8–12 yellow — design review *before the next file lands*. ≥13 red —
**must decompose**. Either zone: run the 3-step design review under "Package
decomposition", printed with this range (it is a *design* review — missing domain types are the
disease, file count the symptom). Invoke @code-designing to validate extracted types.
</package_decomposition>
</file_and_package_routing>

## Preparatory mode

Fowler's preparatory refactoring — "make the change easy, then make the easy change":
reshape code an approved plan is about to touch, before the first RED, so the feature
lands as add-only. Invoked by @linter-driven-development (Phase 1.5, or Phase 2 RED
friction) or `/py-ldd-prepare`, with a DESIGN PLAN, the touch-point file list, and
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

## Stopping criteria, in full

Linter green is where stopping begins, not where it ends. The exit is six actions over
the code this session touched, run in order; each action ends by writing its line of
the `Stop check` block (SKILL.md `<output_format>`). The line is the receipt: an action with no
line has not run, and the line is written when the action finishes, never from memory
at the end. Line `0 slices` precedes them: the slices and waves the script printed and
how each worker ended ("Slices and receipts" above).

1. **Gates.** Linter 0 issues; tests green; functions <50 LOC, nesting ≤2; no red-zone
   packages. Line `1 gates`: the four measurements.
2. **Detection re-run.** One Bash call runs the review's scope and detection scripts
   over the touched files — `S=<this skill dir>/../../scripts; out=$(bash "$S/ldd-scope.sh" <the touched files>); echo "$out"; case "$out" in *'nothing to review') ;; *) bash "$S/ldd-detect.sh" "${out##* }" ;; esac` — and prints the counts table: every falsifying question's detect line over those files, the table the hunters read. For R8 the scope is every file of the touched packages, because a package-level variable, an import-time
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
     the block (SKILL.md `<output_format>`), `file:line — rule and question — what stands`.
     Reported, not fixed, not silent. Replacing one global read inside a brownfield
     function does not make that function's eight-linter `# noqa` this session's
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
   default, never an optional field that may be absent, and an option handed None records the error for
   the constructor to return rather than storing it or substituting the default; a
   value parsed in two places has one constructor; a repeated predicate is a method.
   Score each candidate with R1's scorecard: ≥4 → apply the
   move; 2–3 → apply it or record the judgment call in the STATUS block; 0–1 → leave
   it. A candidate is never skipped because the linter is already quiet. Line
   `3 nouns`: each candidate with its score and verdict — `none scored ≥2` when
   nothing qualified, never a blank.
4. **The comment critic.** Inside the workflow, when Phase 4's review follows this
   session, this step is the review's: its critic reads the touched files' comments
   once, and running one here too would judge the same comments twice. Write
   `4 critic: Phase 4` and go on. Standalone, or when no review follows, spawn one `python-linter-driven-development:comment-critic` (Agent tool, foreground) over
   the touched files with the doctrine paths @pre-commit-review step 3b names, and state the
   scope in the spawn prompt as *every comment in each touched file*, not the changed
   lines — the `Sink is where events are written.` docstring beside the code just
   reshaped restates its name whether or not this session wrote it. Its
   TRIM / REWRITE / DELETE verdicts go to one `Apply comment verdicts` slice — a
   comment edit is small, and the parent still makes none — and its
   `DELETE → route R3` verdicts go back to step 3. Line `4 critic`: the verdict counts
   handed to the slice and routed.
5. **STOP**, and read the over-engineering signs as a check on step 3, never as a
   reason to skip it: a one-method type that merely unwraps, a function that only
   calls another, more layers than concepts — undo that move. Line `5 STOP`: none of
   the signs, or the move undone.
6. **Commits.** Every green move is already a commit: the worker that made it green
   committed it, the move's name first in the subject and the slice's files alone in
   it — and for R8 a slice is one island and its caller (Extract Clean Island, then
   Push the Global Up One Level, one level per move), never every caller threaded at
   once — so the green tree outlives the session. The parent lists those hashes here;
   its own tree is clean, because it edited nothing. Inside the workflow, Phase 5
   commits nothing for the slices and carries these hashes into the ship summary. A
   report that ends with "let me know if you'd like me to commit" or "your call" is
   the failure this step exists to prevent: there is no next turn. Line `6 commit`:
   one `<sha> <subject>` per green move, or `no green move`.

The six lines are the block, and the block goes where the user reads: the message
that ends the turn, whichever path invoked this skill — a standalone invocation's
report, the workflow's Phase 5 ship summary, quickfix's ship summary. A caller that
summarises this skill's work carries the block verbatim above its own summary, and
the BROADER CONTEXT lines under it travel with the block: what step 2 reported instead
of fixing is the caller's to hear, not this session's to bury. Prose
that narrates the steps ("re-ran detection, spawned the critic, committed") in place
of the six lines is the block missing, and a missing block means the refactoring did
not finish.

## Integration

**Invoked by**: @linter-driven-development (Phase 1.5 / RED friction → `<preparatory_mode>`;
Phase 3, lint failures), or the caller acting
on accepted @pre-commit-review findings (@linter-driven-development Phase 4 accepted
findings, or the user) — @pre-commit-review reports only and never invokes fix skills.
**Invokes**: @code-designing (new types/design needed), @testing (after every extraction
— mandatory), @pre-commit-review (after lint passes). **Loop**: lint fails → @refactoring
→ re-lint → @pre-commit-review → repeat until both pass.

## Multi-rule procedures

Procedures that span several rules; single-rule moves are the rules' own.

### Sequencing: which pattern first, and when to stop

Spans R3 × R1 × R2 × R4. Apply least-invasive first; re-run the linter after each move.

1. **Storify first** (R3). Mixed abstraction levels are the most common root cause of
   complexity failures, and storifying *reveals* the structure the later moves need:
   comment-named blocks become functions, boolean loop flags surface as candidate
   types. Never extract a type from a function you haven't storified — you'll extract
   the wrong seams.
2. **Early returns** (R3) — invert conditions, flatten nesting to ≤2 levels.
3. **Extract function** (R3) — split remaining long bodies by responsibility.
4. **Extract type** (R1 + R2) — only when extracted steps share data (loop flags,
   accumulated state) or named behavior runs on a primitive. Score the candidate with
   R1's scorecard *before* creating it; the new type gets a validating constructor
   per R2. Worked pair of moves 1+4: `../../examples/storify-leaf-type.md`.
5. **Place it** (R4) — the ladder decides where the extraction lands: underscore-prefixed
   helper, feature sub-package, or shared domain package.

**When to stop**: the six ordered steps of `<stopping_criteria>` (SKILL.md, in full above) — linter
green is step 1 of 6, never the finish; the detection re-run, the noun check and the
comment critic over the touched files come before STOP, and the commit is step 6.
Warning signs you went past the sweet spot: types with one method that merely unwraps,
functions that only call another function, more abstraction layers than domain
concepts. The worked rejection: `../../examples/overabstraction-cidr.md`.

**Cohesion > coupling**: put logic where it belongs even if that adds a dependency.

### God-object decomposition

Spans R3 × R1 × R4. **Trigger**: a type with >15 methods or >500 LOC.

1. **Storify the methods first** (R3) — reveals the hidden method clusters.
2. **Extract generic logic into leaf types** (R1): string/URL/path handling, retry
   and timeout logic, date formatting, validation. These become independently
   testable islands and often turn out reusable — place them per R4's ladder.
3. **Group the remaining methods by noun** — user methods → `UserService`, cache
   methods → `CacheService` — and extract each group into a focused service type.
4. **Compose the services in an orchestrator** that delegates, not implements.

Key insight: step 2 usually reveals the god object was mixing infrastructure concerns
with domain logic — that mix, not size, is the disease. Forward design of the
composition: @code-designing.

### Package decomposition

Spans R5 × R4 × R1 × R2. **Trigger**: package-size red zone (≥13 non-test `.py`
files at one directory level) or yellow zone (8–12) — detection command and zone
table in `<package_decomposition>` above.

**A package-size violation is a design review, not a mechanical file split.** File
count is the symptom; the disease is usually missing domain types or multiple
vertical slices sharing one package. Run the 3 steps *in order*:

#### Step 1 — Does the package name reflect a real-world domain concept?

Role names and generic containers (never acceptable — the list and naming method are
R5's Design guidance) get renamed *first*; the split follows from the new model.

Naming method for the split — model the real-world relationship:
- The **parent** names the actor/system (the thing that does the work).
- The **sub-package** names the domain object (the thing acted upon) — that's where
  your `pkg.Type` call sites live.
- A worker HAS a job → `worker/` + `worker/job/` (`job.ID`, `job.Status`); a compiler
  HAS tokens → `compiler/` + `compiler/token/`.
- Test: say `pkg.Type` out loud. `job.ID` sounds right; `domain.ID` sounds like Java.

#### Step 2 — Are the existing types well-scoped?

Look *inside* the package before looking at the file list:
- **Primitive obsession** (R1): `apiKey string`, `timeout int` fields with validation
  scattered through top-level functions → extract self-validating types (R2) with
  the behavior attached.
- **Big structs with disjoint method sets**: methods `A() B()` use fields `x y` while
  `D() E()` use `z w` — two types fused together; split them.
- **Top-level functions that belong on a type**: a top-level `normalizeFoo(s)`
  wants to be `Foo.Normalize()`.

Extracting types often shrinks the package below threshold with no sub-package split.
Invoke @code-designing to validate the extractions.

#### Step 3 — Only now, decide the physical split

- Multiple vertical slices in one package → extract sub-packages (Step 1 naming).
- One slice with undermodeled internals → types into their own files, possibly a leaf
  sub-package for pure domain types.
- Often: both.

**Persistence naming**: `Store`, not `Repository` (concrete, not a pattern name). Each
sub-package gets its own Store with focused queries; constructor everywhere:
`NewStore(db *sql.DB, opts ...StoreOption)`.

**Function stutter**: when moving a function into a named package, drop the prefix —
the package provides context. `jira.SanitizeTicketJSON()` → `sanitize.TicketJSON()`;
`job.NewJobID()` → `job.ParseID()`.

**Import direction** (strictly downward — prevents cycles):

```
leaf types (domain)  ← (nothing)
sub-packages         ← leaf types
parent               ← leaf types + sub-packages
cmd/                 ← everything
```

If the parent needs sub-package logic AND the sub-package needs parent types →
extract the shared types into a leaf sub-package both can import. Never invert the
arrow with an interface (`../../rules/R6-test-only-interfaces.md`).

**Phased migration** (each phase must pass tests + linter):
1. Extract leaf types first (domain sub-package) — biggest import update, zero
   behavior change.
2. Extract the simplest sub-package (e.g. pure UPDATE queries, no shared scanner).
3. Extract complex sub-packages (minimal duplication of shared utilities is allowed).
4. Rename the parent last — update all remaining imports.

**PR strategy**: land the decomposition in its own PR, then rebase the feature on the
decomposed structure. Never mix feature changes with package moves.
