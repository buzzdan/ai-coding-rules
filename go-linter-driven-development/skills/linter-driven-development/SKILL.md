---
name: linter-driven-development
description: |
  Orchestrates complete autopilot workflow: design → test → lint → refactor → review → commit.
  AUTO-INVOKES when user wants to implement code: "implement", "ready", "execute", "continue",
  "do step X", "next task", "let's go", "start coding". Runs automatically through all phases
  until commit-ready. Uses parallel linter+review analysis and intelligent combined reports.
  For: features, bug fixes, refactors. Requires: Go project (go.mod).
---

# Linter-Driven Development Workflow

META ORCHESTRATOR for implementation workflow: design → test → lint → refactor → review → commit.
Use for any commit: features, bug fixes, refactors.

## When to Use
- Implementing any code change that should result in a commit
- Need automatic workflow management with quality gates
- Want to ensure: clean code + tests + linting + design validation

## Pre-Flight Check (ALWAYS RUN FIRST)

Before starting the autopilot workflow, verify all conditions are met:

### 1. Confirm Implementation Intent
Look for keywords indicating the user wants to implement code:
- **Direct keywords**: "implement", "ready", "execute", "do", "start", "continue", "next", "build", "create"
- **Step references**: "step 1", "task 2", "next task", "do step X"
- **Explicit invocation**: "@linter-driven-development"

### 2. Verify Go Project
Check that `go.mod` exists in the project root or parent directories.

### 3. Find Project Commands
Discover test and lint commands by reading project documentation:

**Search locations** (in order):
1. Project docs: `README.md`, `CLAUDE.md`, `agents.md`
2. Build configs: `Makefile`, `Taskfile.yaml`, `.golangci.yaml`
3. Git repository root for workspace-level commands

**Extract commands**:
- **Test command**: Look for `go test`, `make test`, `task test`, or similar
- **Lint command**: Look for `golangci-lint run --fix`, `make lint`, `task lintwithfix`, or similar
- **Prefer**: Commands with autofix capability (e.g., `--fix` flag)

**Fallback defaults** (if not found in docs):
- Tests: `go test ./...`
- Linter: `golangci-lint run --fix`

**If fallbacks don't work**:
- Ask user: "What commands should I use for testing and linting?"
- Document discovered commands in project docs for future runs

**Store discovered commands** for use throughout the workflow.

### 4. Identify Plan Context
Scan conversation history (last 50 messages) for:
- Step-by-step implementation plan
- Which step the user wants to implement
- Any design decisions or architectural context

### 5. Decision Tree

✅ **All conditions met → AUTOPILOT ENGAGED**
- Announce: "Engaging autopilot mode for [feature/step description]"
- Proceed directly to Phase 1

❓ **Unclear intent or missing context → ASK FOR CONFIRMATION**
- "I detected you want to implement something. Should I start the autopilot workflow?"
- Clarify which step to implement if multiple options exist

❌ **No plan found → SUGGEST CREATING PLAN FIRST**
- "I don't see an implementation plan. Would you like me to help create one first?"
- Offer to use @code-designing skill for design planning

❌ **Not a Go project → EXPLAIN LIMITATION**
- "This skill requires a Go project with go.mod. Current project doesn't appear to be Go."

## Workflow Phases

### Phase 1: Implementation Foundation

**Design Architecture** (if new types/functions needed):
- Invoke @code-designing skill
- Output: Type design plan with self-validating domain types
- When in plan mode, invoke with plan mode flag

**Write Tests First**:
- Invoke @testing skill for guidance
- Write table-driven tests or testify suites
- Target: 100% coverage on new leaf types

**Implement Code**:
- Follow coding principles from coding_rules.md
- Keep functions <50 LOC, max 2 nesting levels
- Use self-validating types, prevent primitive obsession
- Apply storifying pattern for readable top-level functions

### Gate 1: Tests Must Pass

Run discovered test command (from Pre-Flight Check).

**Loop until tests pass**:
- IF tests fail → Analyze failure → Fix implementation → Re-run
- Once ✅ tests green → Continue to Phase 2

### Phase 2: Parallel Quality Analysis

**Launch 3 analyses in single message (PARALLEL EXECUTION)**:

**Tool Call 1**: Run tests
```
Bash([PROJECT_TEST_COMMAND])
- Verify tests still pass
- Get coverage metrics
```

**Tool Call 2**: Run linter
```
Bash([PROJECT_LINT_COMMAND])
- Run linter with autofix enabled
- Capture exit code + error details
```

**Tool Call 3**: Launch review agent
```
Task(subagent_type: "go-code-reviewer")

Prompt:
"Review these Go files:
[list files from: git diff --name-only main...HEAD | grep '\.go$']

Mode: full"

Note: The go-code-reviewer agent automatically:
- Uses @pre-commit-review skill for analysis guidelines
- Detects 8 categories of design issues
- Returns structured report with effort estimates
- Operates in read-only mode (no changes, no skill invocations)
```

**Wait for all three to complete** before proceeding to Phase 3.

**Time Savings**: ~40-50% faster than sequential execution.

### Phase 3: Intelligent Combined Report

**Collect and Merge Results**:

1. **Gather findings**:
   - Tests: status + coverage
   - Linter: errors with file:line details
   - Review: categorized findings with effort estimates

2. **Group by location**:
   - Organize by file and function/area
   - Identify overlapping issues (same location, multiple findings)

3. **LLM-Powered Root Cause Analysis**:
   For each group of overlapping issues:
   - List all issues (linter + review) at that location
   - Analyze root cause (what's the underlying problem?)
   - Propose unified fix strategy (one fix solves multiple issues)
   - Predict outcome (will this fix resolve all issues?)
   - Score: impact (issues resolved) × effort × risk

4. **Prioritize Fixes**:
   - **Priority 1 - CRITICAL**: Fixes multiple issues with single change
   - **Priority 2 - HIGH VALUE**: Prevents future pain, enables better patterns
   - **Priority 3 - QUICK WINS**: Low effort, clear benefit

5. **Generate Fix Instructions**:
   Create detailed list for @refactoring skill:
   - File and function to fix
   - All issues in that area
   - Unified fix strategy
   - Expected outcome (predicted metrics after fix)

6. **Decision**:
   - IF (linter clean AND review clean) → Skip to Phase 5 (Documentation)
   - ELSE → Proceed to Phase 4 (Auto-fix all issues)

**Example Combined Report**:
```
═══════════════════════════════════════════════════════
INTELLIGENT COMBINED REPORT
═══════════════════════════════════════════════════════

📊 Raw Findings:
  - Linter: 5 errors
  - Review: 8 findings
  - Total: 13 issues

🧠 Analyzing overlapping issues...

┌─────────────────────────────────────────────────────┐
│ pkg/parser.go:45 - function Parse                   │
│ OVERLAPPING ISSUES (4):                             │
│                                                      │
│ ⚠️ Linter: Cognitive complexity 18 (>15)           │
│ ⚠️ Linter: Function length 58 statements (>50)     │
│ 🔴 Review: Mixed abstraction levels                 │
│ 🔴 Review: Defensive null checking                  │
│                                                      │
│ 🎯 ROOT CAUSE: Function handles 4 responsibilities  │
│ 💡 UNIFIED FIX: Apply STORIFYING pattern            │
│    - Extract parseRawInput() (low-level)           │
│    - Extract validateFields() (mid-level)          │
│    - Extract buildResult() (high-level)            │
│    - Main function orchestrates (single level)     │
│                                                      │
│ ✅ EXPECTED: All 4 issues resolved!                │
│    Complexity: 18 → ~8 | Length: 58 → ~25         │
│                                                      │
│ Priority: #1 CRITICAL (Impact: HIGH, Effort: MOD)  │
└─────────────────────────────────────────────────────┘

🎯 Total Issues: 13
🎯 Total Fixes: 3 (smart grouping!)
🎯 Expected Result: All checks green

Proceeding to Phase 4 with automated fixes...
```

### Phase 4: Iterative Fix Loop

**For each prioritized fix** (from Phase 3):

1. **Apply Fix**:
   - Invoke @refactoring skill with:
     * File and function to fix
     * All issues in that area
     * Unified fix strategy from Phase 3
     * Expected outcome
   - @refactoring applies appropriate patterns:
     * Early returns (reduce nesting)
     * Extract function (break complexity)
     * Storifying (uniform abstractions)
     * Extract type (create domain types)
     * Switch extraction (categorize cases)
     * Extract constant (remove magic numbers)

2. **Verify Fix (PARALLEL)**:
   Launch 3 verifications simultaneously:

   - **Tool 1**: Run tests
     ```
     Bash([PROJECT_TEST_COMMAND])
     ```

   - **Tool 2**: Run linter
     ```
     Bash([PROJECT_LINT_COMMAND])
     ```

   - **Tool 3**: Launch review agent in INCREMENTAL mode
     ```
     Task(subagent_type: "go-code-reviewer")

     Prompt:
     "Review these Go files:
     [list files from: git diff --name-only HEAD~1 HEAD | grep '\.go$']

     Mode: incremental

     Previous findings:
     [paste findings from Phase 3 combined report]"

     Note: Agent returns delta report:
     - ✅ Fixed: Issues resolved since last run
     - ⚠️ Remaining: Issues still present
     - 🆕 New: Issues introduced by recent changes
     ```

3. **Check Status**:
   - ✅ All pass → Continue to next fix or Phase 5
   - ❌ Still failing → Analyze new issues, apply next pattern

4. **Safety Limits**:
   - Max 10 iterations per phase
   - IF stuck → Show current status, ask user for guidance
   - User can review: `git diff`

**Loop until**:
- ✅ Tests pass
- ✅ Linter clean
- ✅ Review clean

### Gate 2: All Quality Checks Green

**Final parallel verification**:
```
├─ [PROJECT_TEST_COMMAND]  ✅
├─ [PROJECT_LINT_COMMAND]  ✅
└─ Review report           ✅
```

Once all green → Continue to Phase 5

### Phase 5: Documentation

Invoke @documentation skill:

1. Add/update package-level godoc
2. Add/update type-level documentation
3. Add/update function documentation (WHY not WHAT)
4. Add godoc testable examples (Example_* functions)
5. IF last plan step:
   - Add feature documentation to docs/ folder

**Verify**:
- Run: `go doc -all ./...`
- Ensure examples compile
- Check documentation coverage

### Phase 6: Commit Ready

Generate comprehensive summary with suggested commit message.

- Linter passes ✅
- Tests pass with coverage ✅
- Design review complete ✅
- Documentation complete ✅
- Present commit message suggestion

## Output Format

```
📋 COMMIT READINESS SUMMARY

✅ Linter: Passed (0 issues)
✅ Tests: 95% coverage (3 new types, 15 test cases)
⚠️  Design Review: 4 findings (see below)

🎯 COMMIT SCOPE
Modified:
- user/service.go (+45, -12 lines)
- user/repository.go (+23, -5 lines)

Added:
- user/user_id.go (new type: UserID)
- user/email.go (new type: Email)

Tests:
- user/service_test.go (+120 lines)
- user/user_id_test.go (new)
- user/email_test.go (new)

⚠️  DESIGN REVIEW FINDINGS

🔴 DESIGN DEBT (Recommended to fix):
- user/service.go:45 - Primitive obsession detected
  Current: func GetUserByID(id string) (*User, error)
  Better:  func GetUserByID(id UserID) (*User, error)
  Why: Type safety, validation guarantee, prevents invalid IDs
  Fix: Use @code-designing to convert remaining string usages

🟡 READABILITY DEBT (Consider fixing):
- user/service.go:78 - Mixed abstraction levels in CreateUser
  Function mixes high-level steps with low-level validation details
  Why: Harder to understand flow at a glance
  Fix: Use @refactoring to extract validation helpers

🟢 POLISH OPPORTUNITIES:
- user/repository.go:34 - Function naming could be more idiomatic
  SaveUser → Save (method receiver provides context)

📝 BROADER CONTEXT:
While reviewing user/service.go, noticed 3 more instances of string-based
IDs throughout the file (lines 120, 145, 203). Consider refactoring the
entire file to use UserID consistently for better type safety.

💡 SUGGESTED COMMIT MESSAGE
Add self-validating UserID and Email types

- Introduce UserID type with validation (prevents empty IDs)
- Introduce Email type with RFC 5322 validation
- Refactor CreateUser to use new types
- Achieve 95% test coverage with real repository implementation

Follows vertical slice architecture and primitive obsession principles.

────────────────────────────────────────

Would you like to:
1. Commit as-is (ignore design findings)
2. Fix design debt only (🔴), then commit
3. Fix design + readability debt (🔴 + 🟡), then commit
4. Fix all findings (🔴 🟡 🟢), then commit
5. Refactor entire file (address broader context), then commit
```

## Workflow Control

**Sequential Phases**: Each phase depends on previous phase completion
- Design must complete before implementation
- Implementation must complete before linting
- Linting must pass before review
- Review must complete before commit

**Iterative Linting**: Phase 3 loops until clean
**Advisory Review**: Phase 4 never blocks, always asks user

## Integration with Other Skills

This orchestrator **invokes** other skills automatically:
- @code-designing (Phase 1, if needed)
- @testing (Phase 2, principles applied)
- @refactoring (Phase 3, when linter fails)
- @pre-commit-review (Phase 4, always)

After committing, consider:
- If feature complete → invoke @documentation skill
- If more work needed → run this workflow again for next commit
