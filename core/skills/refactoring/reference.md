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
| Move test down a rung, Split Success and Error Tables, Replace sleep with synchronization | `../../rules/R7-test-placement.md` |
| Extract Clean Island, Push Global Up One Level, Replace Import-Time Initialization with a Constructor, Pass Cancellation Down | `../../rules/R8-no-globals.md` |
| Inject the Exit Path, Make Concurrent Work Joinable, Extract Synchronized Owner, Replace Sleep with Cancellable Wait, Delete Unearned Guards | `../../rules/R10-concurrency-safety.md` |
| Replace Duplicated Switch with Interface Dispatch, Replace If-Chain with Strategy Map, Introduce Null Object, Split Flag Argument, Keep the Single Exhaustive Switch | `../../rules/R11-conditional-dispatch.md` |
| Copy on the Way In, Copy on the Way Out / Encapsulate Collection, Separate Query from Modifier, Remove Setting Method, Split Variable | `../../rules/R12-mutation-discipline.md` |

**Introduce Null Object, the shape.** The null object is a *named* value of the
collaborator's existing concrete type — a sink composing the standard no-op writer, a
clock that is the real clock — supplied as the constructor's default through an option
or passed by the caller by name. Never a new interface with one no-op implementation
(R6), never a {{.Nil}} parameter that means "default" (R2). An option handed {{.Nil}}
records the error on the value under construction and the constructor fails with it
(R2's example) — the option never substitutes the default and never stores the
{{.Nil}}.

{{include "skills/refactoring/null-object-mechanics.md"}}

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

## File and package routing

<file_and_package_routing>
{{include "skills/refactoring/file-and-package-routing.md"}}
</file_and_package_routing>

## Preparatory mode

Fowler's preparatory refactoring — "make the change easy, then make the easy change":
reshape code an approved plan is about to touch, before the first RED, so the feature
lands as add-only. Invoked by @linter-driven-development (Phase 1.5, or Phase 2 RED
friction) or `/{{.CmdPrefix}}-prepare`, with a DESIGN PLAN, the touch-point file list, and
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
at the end.

1. **Gates.** Linter 0 issues; tests green; functions <50 LOC, nesting ≤2; no red-zone
   packages. Line `1 gates`: the four measurements.
2. **Detection re-run.** Re-run the detection commands (each rule's Falsifying
   questions) of every rule routed in this session over the touched files — and for
   R8 over the touched packages, because a package-level variable, an import-time
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
     function does not make that function's eight-linter `{{.Nolint}}` this session's
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
   default, never an optional field that may be absent, and an option handed {{.Nil}} records the error for
   the constructor to return rather than storing it or substituting the default; a
   value parsed in two places has one constructor; a repeated predicate is a method.
   Score each candidate with R1's scorecard: ≥4 → apply the
   move; 2–3 → apply it or record the judgment call in the STATUS block; 0–1 → leave
   it. A candidate is never skipped because the linter is already quiet. Line
   `3 nouns`: each candidate with its score and verdict — `none scored ≥2` when
   nothing qualified, never a blank.
4. **The comment critic.** Spawn one `{{.Plugin}}:comment-critic` (Agent tool, foreground) over
   the touched files with the doctrine paths @pre-commit-review step 3b names, and state the
   scope in the spawn prompt as *every comment in each touched file*, not the changed
   lines — the `Sink is where events are written.` {{.DocForm}} beside the code just
   reshaped restates its name whether or not this session wrote it. Apply its
   TRIM / REWRITE / DELETE verdicts — a comment edit is small — and route its
   `DELETE → route R3` verdicts back to step 3. Line `4 critic`: the verdict counts
   applied and routed.
5. **STOP**, and read the over-engineering signs as a check on step 3, never as a
   reason to skip it: a one-method type that merely unwraps, a function that only
   calls another, more layers than concepts — undo that move. Line `5 STOP`: none of
   the signs, or the move undone.
6. **Commit.** Tests and lint green and the tree dirty → `git commit` with the STATUS
   block's summary as the message — one commit per green step when the caller asked
   for deployable steps, and for R8 a step is one island and its caller (Extract Clean
   Island, then Push the Global Up One Level, one level per commit), never every
   caller threaded at once — so the green tree outlives the session. Inside the
   workflow, Phase 5 commits the slice it ships; a standalone invocation commits
   here, now, before the report. A report that ends with "let me know if you'd like
   me to commit" or "your call" is the failure this step exists to prevent: there is
   no next turn. Line `6 commit`: the hash and message, `Phase 5 commits the slice`,
   or `tree clean, nothing to commit`.

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
5. **Place it** (R4) — the ladder decides where the extraction lands: {{.Unexported}}
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

Spans R5 × R4 × R1 × R2. **Trigger**: package-size red zone (≥13 non-test `{{.SrcExt}}`
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
