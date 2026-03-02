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
  - mcp__ide__getDiagnostics
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
</refactoring_signals>

<pattern_summary>
**Pattern Priority Order** (for complexity failures):

1. **Storifying** - Make code read like a story, reveals hidden structure
2. **Early Returns** - Reduce nesting by inverting conditions
3. **Extract Function** - Break up long functions by responsibility
4. **Extract Type** - Create domain types (only if "juicy")
5. **Switch Extraction** - Extract case handlers to separate functions
6. **Dependency Rejection** - Push globals up call chain incrementally

See `reference.md` for detailed patterns with code examples.

<juiciness_test>
Before extracting a type, verify it's "juicy" (worth creating):

**BEHAVIORAL**: Complex validation, ≥2 meaningful methods, state transitions
**STRUCTURAL**: Parsing unstructured data, grouping related data
**USAGE**: Used in multiple places, simplifies calling code

Need "yes" in at least ONE category. See `reference.md` section 2.5 for over-abstraction warnings.
</juiciness_test>

<type_cohesion>
When extracting a type to its own file, co-locate ALL related declarations:
- Type definition + constants + constructor + all methods

Verify: `grep -r "TypeName" --include="*.go" . | grep -v "type_file.go"`
If found elsewhere → move to type's file
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
1. List all types created: `grep -r "^type.*struct" internal/`
2. Verify test file exists for each type
3. If missing: STOP and invoke @testing skill to write tests
4. Coverage check: `go test -cover ./...` - leaf types must show 100%
5. Scan for nolint in all uncommitted files (staged + unstaged):
   ```bash
   { git diff --name-only; git diff --cached --name-only; } | sort -u | xargs grep "//nolint" 2>/dev/null
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
{ git diff --name-only; git diff --cached --name-only; } | sort -u | xargs grep "//nolint" 2>/dev/null
```
If found → STOP and fix properly

See `reference.md` for acceptable exceptions (rare, requires user approval).
</nolint_prohibition>

<stopping_criteria>
**STOP when ALL are met:**
- Linter passes (0 issues)
- All functions < 50 LOC
- Nesting ≤ 2 levels
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
- [ ] Tests written for new types/functions (via @testing skill)
- [ ] Ready for @pre-commit-review phase
</success_criteria>
