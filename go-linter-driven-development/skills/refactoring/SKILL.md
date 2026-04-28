---
name: refactoring
description: |
  Linter-driven refactoring patterns to reduce complexity and improve code quality.
  Use when linter fails with complexity issues (cyclomatic, cognitive, maintainability) or when code feels hard to read/maintain.
  Applies storifying, type extraction, and function extraction patterns.
allowed-tools:
  - Skill(go-linter-driven-development:code-designing)
  - Skill(go-linter-driven-development:testing)
  - Skill(go-linter-driven-development:pre-commit-review)
---

<objective>
Linter-driven refactoring patterns to reduce complexity and improve code quality.
Operates autonomously - no user confirmation needed during execution.

**Reference**: See `reference.md` for complete decision tree, patterns, and code examples.
**Examples**: See `examples.md` for real-world refactoring case studies.
</objective>

<skill_invocation>
**CRITICAL**: When this skill says "Invoke @skill-name" or routes to "@skill-name", you MUST use the **Skill tool** explicitly.

| Notation | Skill Tool Call |
|----------|-----------------|
| @code-designing | `Skill(go-linter-driven-development:code-designing)` |
| @testing | `Skill(go-linter-driven-development:testing)` |
| @pre-commit-review | `Skill(go-linter-driven-development:pre-commit-review)` |

**DO NOT** just reference the skill - actually invoke it using the Skill tool.
</skill_invocation>

<quick_start>
1. **Receive linter failures** from @linter-driven-development
2. **Analyze root cause** - Does it read like a story? Can it be broken down?
3. **Apply patterns** in priority order (storify → early returns → extract function → extract type)
4. **Verify** - Re-run linter automatically
5. **Iterate** until linter passes

**IMPORTANT**: This skill operates autonomously - no user confirmation needed.
</quick_start>

<when_to_use>
- **Automatically invoked** by @linter-driven-development when linter fails
- **Automatically invoked** by @pre-commit-review when design issues detected
- **Complexity failures**: cyclomatic, cognitive, maintainability index
- **Architectural failures**: noglobals, gochecknoinits, gochecknoglobals
- **Design smell failures**: dupl, goconst, ineffassign
- **Package size violations**: ≥13 non-test `.go` files at one directory level (red zone, must decompose) or 8–12 (yellow zone, design review before next file)
- Functions > 50 LOC or nesting > 2 levels
- Mixed abstraction levels in functions
- Manual invocation when code feels hard to read/maintain
</when_to_use>

<learning_resources>
- **Quick Start**: Use patterns below for common cases
- **Complete Reference**: See [reference.md](./reference.md) for full decision tree and all patterns
- **Real-World Examples**: See [examples.md](./examples.md) for case studies:
  - **Example 1**: Storifying mixed abstractions + extracting leaf types (fat function → lean orchestration)
  - **Example 2**: Primitive obsession with multiple types + switch elimination (includes over-abstraction trap!)
  - **Example 3**: Dependency rejection pattern (globals → clean testable islands, bottom-up approach)
</learning_resources>

<refactoring_signals>

<linter_routing>
| Linter Error | Pattern |
|--------------|---------|
| `nestif` (deep nesting) | Storify → Early returns → Extract function |
| `cyclop`/`gocognit` | Storify → Extract type |
| `funlen` (too long) | Storify → Extract function |
| `noglobals` | Dependency rejection |
| `dupl` | Extract common logic/types |
| `goconst` | Extract constants or types |
| `wrapcheck` | Direct fix: `fmt.Errorf("context: %w", err)` |
| `early-return` (revive) | Invert condition, return early |
| `file-length-limit` | Route to @code-designing for file splitting |

**Pattern Documentation**:
- Storifying, Early Returns, Extract Function, Extract Type → `reference.md`
- Dependency Rejection → `examples.md` (Example 3)
- Over-abstraction warnings → `reference.md` section 2.5
</linter_routing>

<file_level_concerns>
**When `file-length-limit` triggers (>450 lines):**

| File Pattern | Route To | Action |
|--------------|----------|--------|
| Multiple juicy types | @code-designing | Juicy type per file |
| Single god type (>15 methods) | @refactoring → @code-designing | Storify, then decompose |
| Long functions, few types | @refactoring | Storify → Extract functions |

**"Juicy" types** (deserve own file): ≥2 methods, complex validation, transformations/parsing
**Anemic types** (can stay grouped): Simple enums, DTOs without methods, type aliases
</file_level_concerns>

<package_level_concerns>
**Detection is automatic.** This plugin ships a PostToolUse hook (`hooks/check-package-sizes.sh`) that counts non-test `.go` files per package after every Write / Edit / MultiEdit and surfaces violations directly to Claude.

| Count | Zone   | Action                                                                          |
|-------|--------|---------------------------------------------------------------------------------|
| ≤ 7   | Green  | Fine.                                                                           |
| 8–12  | Yellow | Advisory from hook (non-blocking). Design review **before the next file lands** — route to `<package_decomposition>`. |
| ≥ 13  | Red    | Blocking feedback from hook (exit 2). **Must decompose** — route to `<package_decomposition>`. |

**Critical**: A package-size violation is a *design* review (domain modeling + type extraction), not a mechanical file split. File count is a symptom; the disease is usually missing domain types or multiple vertical slices sharing a package.
</package_level_concerns>
</refactoring_signals>

<pattern_summary>
**Pattern Priority Order** (for complexity failures):

1. **Storifying** - Make code read like a story, reveals hidden structure
2. **Early Returns** - Reduce nesting by inverting conditions
3. **Extract Function** - Break up long functions by responsibility
4. **Extract Type** - Create domain types (only if "juicy")
5. **Switch Extraction** - Extract case handlers to separate functions
6. **Dependency Rejection** - Push globals up call chain incrementally
7. **Package Decomposition** - Split oversized packages (≥13 files) via 3-step design review (see `<package_decomposition>`)

See `reference.md` for detailed patterns with code examples.

<juiciness_test>
Before extracting a type, verify it's "juicy" (worth creating):

**BEHAVIORAL**: Complex validation, ≥2 meaningful methods, state transitions
**STRUCTURAL**: Parsing unstructured data, grouping related data
**USAGE**: Used in multiple places, simplifies calling code

Need "yes" in at least ONE category. See `reference.md` section 2.5 for over-abstraction warnings.

**Self-Validation Rule:** Extracted types must own their validation. The original function stops validating what the new type now owns. Composed self-validating types are trusted, not re-validated.
</juiciness_test>

<type_cohesion>
When extracting a type to its own file, co-locate ALL related declarations:
- Type definition + constants + constructor + all methods

Verify by searching for *declarations* tied to the type, not every usage of its name
(usages in tests, comments, and other packages are false positives). Check for:
- Receiver methods: `grep -RnE '^func \([^)]+\*?TypeName\)' --include="*.go" .`
- Constructors: `grep -RnE '^func (New|Parse|Make)TypeName\b' --include="*.go" .`
- Related `const`/`var` declarations that belong with the type.

If declarations that should be co-located are found elsewhere → move them to the type's file.
</type_cohesion>

<god_object_decomposition>
**Trigger**: Type has >15 methods OR >500 LOC

**Strategy** (in order):

1. **Extract generic logic first** (creates reusable leaf types):
   - String manipulation → `StringParser`, `Formatter` types
   - URL/path handling → `URL`, `FilePath` types with validation
   - Retry/timeout logic → `Retrier`, `TimeoutHandler` types
   - Date/time formatting → `DateFormatter` type
   - Validation patterns → Self-validating domain types

   These become **testable islands** and may be useful elsewhere.

2. **Then group remaining methods by noun** (domain services):
   - User methods → `UserService`
   - Order methods → `OrderService`
   - Cache methods → `CacheService`

3. **Extract each group into focused service type**
4. **Compose services in orchestrator** (delegates, doesn't implement)

**Key insight**: Generic logic extraction often reveals the god object was mixing infrastructure concerns with domain logic.

See `reference.md` for detailed example.
</god_object_decomposition>

<package_decomposition>
**Trigger**: PostToolUse hook reports a package in the red zone (≥13 non-test `.go` files at one directory level) or yellow zone (8–12). Detection is handled by `hooks/check-package-sizes.sh`; this section is the authoritative HOW for responding.

**A package-size violation is a design review, not a mechanical file split.** Run the 3 steps *in order*:

**Step 1 — Does the package name reflect a real-world domain concept?**

Anti-patterns (rename *first*, the split follows from the new model):
- Role names: `handlers/`, `types/`, `model/`
- Containers: `common/`, `shared/`, `core/`, `base/`, `util/`, `domain/`

Naming method for the split:
- The **parent** names the actor/system (the thing that does the work).
- The **sub-package** names the domain object (the thing being acted upon). This is where `pkg.Type` call sites live — they must read like English.

Examples:
- A worker HAS a job → `worker/` + `worker/job/` (`job.ID`, `job.Status`)
- A compiler HAS tokens → `compiler/` + `compiler/token/`
- A scheduler HAS tasks → `scheduler/` + `scheduler/task/`

Test: say `pkg.Type` out loud. `job.ID` sounds right. `domain.ID` sounds like Java.

**Step 2 — Are the existing types well-scoped?**

Look *inside* the package before looking at the file list:
- **Primitive obsession**: fields like `apiKey string`, `email string`, `timeout int` with validation scattered through top-level functions → extract self-validating types (`APIKey`, `Email`, `Timeout`) with the behavior attached.
- **Big structs with disjoint method sets**: methods `A() B() C()` use fields `x y` while methods `D() E()` use fields `z w` — that's two types fused together. Split them.
- **Top-level functions that belong on a type**: `func normalizeFoo(s string) string` almost always wants to be `(f Foo) Normalize()` on a `Foo` type.

Extracting types often shrinks the package below threshold without any sub-package split — file count is the symptom, missing types are the disease. Invoke @code-designing to validate juicy type extractions.

**Step 3 — Only now, decide the physical split.**

- Multiple vertical slices in one package → extract sub-packages (Step 1 naming).
- One slice with undermodeled internals → extract types into their own files, possibly a leaf sub-package for pure domain types.
- Often: both.

**Persistence naming**: use `Store`, not `Repository` (Go-idiomatic, concrete). Each sub-package gets its own Store with focused queries. Constructor pattern everywhere: `NewStore(db *sql.DB, opts ...StoreOption)`.

**Function stutter**: when moving a function to a named package, drop the prefix — the package provides context. `jira.SanitizeTicketJSON()` → `sanitize.TicketJSON()`. `job.NewJobID()` → `job.ParseID()`.

**Import direction** (strictly downward — prevents cycles):
```
leaf types (domain)  ← (nothing)
sub-packages         ← leaf types
parent               ← leaf types + sub-packages
cmd/                 ← everything
```
If the parent needs sub-package logic AND the sub-package needs parent types → extract the shared types into a leaf sub-package.

**Phased migration** (each phase must pass tests + linter):
1. Extract leaf types first (domain sub-package) — biggest import update, zero behavior change.
2. Extract the simplest sub-package (e.g., pure UPDATE queries, no shared scanner).
3. Extract complex sub-packages (may need minimal duplication of shared utilities).
4. Rename parent last — update all remaining imports.

**PR strategy**: land the decomposition in its own PR, then rebase the feature against the decomposed structure. Do not mix feature changes with package moves.
</package_decomposition>
</pattern_summary>

<automation_flow>
<iteration_loop>
1. Receive trigger (automatic from other skills, or manual user request)
2. Apply refactoring pattern (start with least invasive)
3. Run linter immediately (no user confirmation)
4. If linter still fails → try next pattern in priority order
5. Repeat until linter passes
6. If patterns exhausted → report what was tried, escalate to user for architectural guidance
</iteration_loop>

<no_manual_intervention>
- **NO** asking for confirmation between patterns
- **NO** waiting for user input
- **AUTOMATIC** progression through patterns
- **ONLY** report results at the end
</no_manual_intervention>
</automation_flow>

<testing_integration>
**MANDATORY**: After creating new types or extracting functions, invoke @testing skill.

<enforcement>
Before marking refactoring complete:
1. List all types created: `grep -RnE "^type[[:space:]]+\w+[[:space:]]+struct" --include="*.go" .`
2. Verify test file exists for each type
3. If missing: STOP and invoke @testing skill to write tests
4. Coverage check: `go test -cover ./...` - leaf types must show 100%
5. Scan for nolint in all uncommitted files (staged + unstaged):
   ```bash
   changed_files=$({ git diff --name-only; git diff --cached --name-only; } | sort -u)
   if [ -n "$changed_files" ]; then
     printf '%s\n' "$changed_files" | xargs grep "//nolint" 2>/dev/null
   fi
   ```
   If found → remove directive and fix properly (see `<nolint_prohibition>` section)

**BLOCKING**: Do not proceed until tests exist AND no nolint directives in changed files.
</enforcement>

<workflow>
1. Extract type during refactoring
2. Immediately invoke @testing skill
3. @testing skill writes appropriate tests
4. Verify tests pass
5. Continue refactoring
</workflow>
</testing_integration>

<nolint_prohibition>
**NEVER use `//nolint` directives to avoid refactoring.**

Instead:
- Handle errors (log as fallback, use t.Log in tests)
- Validate input at boundaries
- Refactor to reduce complexity

**Verification**: After refactoring, scan for nolint in all uncommitted files (staged + unstaged):
```bash
changed_files=$({ git diff --name-only; git diff --cached --name-only; } | sort -u)
if [ -n "$changed_files" ]; then
  printf '%s\n' "$changed_files" | xargs grep "//nolint" 2>/dev/null
fi
```
If found → STOP and fix properly

See `reference.md` for acceptable exceptions (rare, requires user approval).
</nolint_prohibition>

<stopping_criteria>
**STOP when ALL are met:**
- Linter passes (0 issues)
- All functions < 50 LOC
- Nesting ≤ 2 levels
- No packages in red zone (≥13 non-test `.go` files at one directory level)
- Code reads like a story
- No more "juicy" abstractions to extract

**Warning Signs of Over-Engineering:**
- Types with only one method
- Functions that just call another function
- More abstraction layers than necessary
- Code becomes harder to understand

IF linter passes AND code is readable → STOP (avoid abstraction bloat)
</stopping_criteria>

<output_format>
```
REFACTORING APPLIED

Patterns Applied:
1. [Pattern]: [What changed]
2. [Pattern]: [What changed]

Types Created (with Juiciness Score):
- [Type] (JUICY - [reason]): [methods]
  → Invoke @testing skill

Types Rejected (NOT JUICY):
- [Type]: [reason - good naming sufficient]

Metrics:
- Cyclomatic: [before] → [after]
- LOC: [before] → [after]
- Nesting: [before] → [after]

Files Modified:
- [file] (+X, -Y lines)

Created (Islands of Clean Code):
- [file] (new) → Ready for @testing skill

STATUS: [Linter passes / Still failing: X issues]
```
</output_format>

<integration>
**Invoked By**:
- @linter-driven-development: When linter fails (Phase 3)
- @pre-commit-review: When design issues detected

**Invokes**:
- @code-designing: When file splitting needed or new types require design validation
- @testing: After creating new types/functions (MANDATORY)
- @pre-commit-review: After linting passes (validates design quality)

**Loop**: Linter fails → @refactoring → re-run linter → @pre-commit-review → repeat until both pass
</integration>

<success_criteria>
Refactoring is complete when ALL are true:

- [ ] Linter passes (0 issues)
- [ ] All functions < 50 LOC
- [ ] Max nesting ≤ 2 levels
- [ ] Code reads like a story
- [ ] No more "juicy" abstractions to extract
- [ ] No packages in red zone (the plugin's PostToolUse hook passes with no RED output; see `<package_level_concerns>`)
- [ ] Tests written for new types/functions (via @testing skill)
- [ ] Ready for @pre-commit-review phase
</success_criteria>
