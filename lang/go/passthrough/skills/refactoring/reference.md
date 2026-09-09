# Multi-Rule Refactoring Procedures

Single-rule moves live in the rules' **Fix pattern** sections
(`../../rules/R1-primitive-obsession.md` … `R8-no-globals.md`) — apply them from
there. This file holds only the procedures that genuinely span multiple rules.
Deep worked case law: `../../examples/`.

## Sequencing: which pattern first, and when to stop

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
5. **Place it** (R4) — the ladder decides where the extraction lands: unexported
   helper, feature sub-package, or shared domain package.

**When to stop**: linter green + top-level reads like a story + every remaining type
candidate scores LOW on R1's scorecard → STOP. Warning signs you went past the
sweet spot: types with one method that merely unwraps, functions that only call
another function, more abstraction layers than domain concepts. The worked rejection:
`../../examples/overabstraction-cidr.md`.

**Cohesion > coupling**: put logic where it belongs even if that adds a dependency.

## God-object decomposition

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

## Package decomposition

Spans R5 × R4 × R1 × R2. **Trigger**: package-size red zone (≥13 non-test `.go`
files at one directory level) or yellow zone (8–12) — detection command and zone
table in SKILL.md `<package_decomposition>`.

**A package-size violation is a design review, not a mechanical file split.** File
count is the symptom; the disease is usually missing domain types or multiple
vertical slices sharing one package. Run the 3 steps *in order*:

### Step 1 — Does the package name reflect a real-world domain concept?

Role names and generic containers (never acceptable — the list and naming method are
R5's Design guidance) get renamed *first*; the split follows from the new model.

Naming method for the split — model the real-world relationship:
- The **parent** names the actor/system (the thing that does the work).
- The **sub-package** names the domain object (the thing acted upon) — that's where
  your `pkg.Type` call sites live.
- A worker HAS a job → `worker/` + `worker/job/` (`job.ID`, `job.Status`); a compiler
  HAS tokens → `compiler/` + `compiler/token/`.
- Test: say `pkg.Type` out loud. `job.ID` sounds right; `domain.ID` sounds like Java.

### Step 2 — Are the existing types well-scoped?

Look *inside* the package before looking at the file list:
- **Primitive obsession** (R1): `apiKey string`, `timeout int` fields with validation
  scattered through top-level functions → extract self-validating types (R2) with
  the behavior attached.
- **Big structs with disjoint method sets**: methods `A() B()` use fields `x y` while
  `D() E()` use `z w` — two types fused together; split them.
- **Top-level functions that belong on a type**: `func normalizeFoo(s string) string`
  wants to be `(f Foo) Normalize()`.

Extracting types often shrinks the package below threshold with no sub-package split.
Invoke @code-designing to validate the extractions.

### Step 3 — Only now, decide the physical split

- Multiple vertical slices in one package → extract sub-packages (Step 1 naming).
- One slice with undermodeled internals → types into their own files, possibly a leaf
  sub-package for pure domain types.
- Often: both.

**Persistence naming**: `Store`, not `Repository` (Go-idiomatic, concrete). Each
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
