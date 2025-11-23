<overview>
This meta-orchestrator skill coordinates other skills. See individual skill reference files for detailed principles.
</overview>

<phase_references>
**Phase 1: Design** → See @code-designing skill
- Type design principles
- Primitive obsession prevention
- Self-validating types
- Vertical slice architecture

**Phase 2: Implementation & Testing** → See @testing skill
- Testing principles
- Table-driven tests
- Testify suites
- Real implementations over mocks

**Phase 3: Linter & Refactoring** → See @refactoring skill
- Linter signal interpretation
- Refactoring patterns
- Complexity reduction strategies

**Phase 4: Pre-Commit Review** → See @pre-commit-review skill
- Design principles checklist
- Debt categorization
- Review process
</phase_references>

<linter_commands>
<primary_command>
```bash
task lintwithfix
```
Runs:
1. `go vet` - Static analysis
2. `golangci-lint fmt` - Format code
3. `golangci-lint run --fix` - Lint with auto-fix
</primary_command>

<fallback_command>
```bash
golangci-lint run --fix
```
Use when no taskfile is available.
</fallback_command>

<configuration>
- Config file: `.golangci.yaml` in project root
- Always use golangci-lint v2
- Reference: https://github.com/golangci/golangci-lint/blob/HEAD/.golangci.reference.yml
</configuration>
</linter_commands>

<linter_signals>
<signal name="cyclomatic_complexity">
**Signal**: Function too complex (too many decision points)
**Action**: Extract functions, simplify logic flow
**Skill**: @refactoring
</signal>

<signal name="cognitive_complexity">
**Signal**: Function hard to understand (nested logic, mixed abstractions)
**Action**: Storifying, extract helpers, clarify abstraction levels
**Skill**: @refactoring
</signal>

<signal name="maintainability_index">
**Signal**: Code difficult to maintain
**Action**: Break into smaller pieces, improve naming, reduce coupling
**Skill**: @refactoring + potentially @code-designing
</signal>
</linter_signals>

<coverage_targets>
<target name="leaf_types">
- **Target**: 100% unit test coverage
- **Why**: Leaf types contain core logic, must be bulletproof
- **Test**: Only public API, use pkg_test package
</target>

<target name="orchestrating_types">
- **Target**: Integration test coverage
- **Why**: Test seams between components
- **Test**: Can overlap with leaf type coverage
</target>
</coverage_targets>

<commit_readiness>
All must be true:
- Linter passes with 0 issues
- Tests pass
- Target coverage achieved (100% for leaf types)
- Design review complete (advisory, but acknowledged)
</commit_readiness>

<agent_prompt_templates>
<template name="quality_analyzer_full">
**Use for**: Initial quality analysis in Phase 2

```
Task(subagent_type: "go-linter-driven-development:quality-analyzer")

Prompt:
"Analyze code quality for this Go project.

Mode: full

Project commands:
- Test: [PROJECT_TEST_COMMAND from Pre-Flight Check]
- Lint: [PROJECT_LINT_COMMAND from Pre-Flight Check]

Files to analyze:
[list files from: git diff --name-only main...HEAD | grep '\.go$']

Run all quality gates in parallel and return combined analysis."
```
</template>

<template name="quality_analyzer_incremental">
**Use for**: Verification after each fix in Phase 3

```
Task(subagent_type: "go-linter-driven-development:quality-analyzer")

Prompt:
"Re-analyze code quality after refactoring.

Mode: incremental

Project commands:
- Test: [PROJECT_TEST_COMMAND]
- Lint: [PROJECT_LINT_COMMAND]

Files to analyze (changed):
[list files from: git diff --name-only HEAD~1 HEAD | grep '\.go$']

Previous findings:
[paste findings from previous quality-analyzer report]

Run quality gates and return delta report (what changed)."
```
</template>
</agent_prompt_templates>

<example_reports>
<example name="issues_found_report">
**Status**: ISSUES_FOUND

This is what the quality-analyzer agent returns when issues are found:

```
═══════════════════════════════════════════════════════
QUALITY ANALYSIS REPORT
Mode: FULL
Files analyzed: 8
═══════════════════════════════════════════════════════

📊 SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Tests: ✅ PASS (coverage: 87%)
Linter: ❌ FAIL (5 errors)
Review: ⚠️ FINDINGS (8 issues: 0 bugs, 3 design, 4 readability, 1 polish)

Total issues: 13 from 3 sources

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OVERLAPPING ISSUES ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Found 3 locations with overlapping issues:

┌─────────────────────────────────────────────────────┐
│ pkg/parser.go:45 - function Parse                   │
│ OVERLAPPING (4 issues):                             │
│                                                      │
│ ⚠️ Linter: Cognitive complexity 18 (>15)           │
│ ⚠️ Linter: Function length 58 statements (>50)     │
│ 🔴 Review: Mixed abstraction levels                 │
│ 🔴 Review: Defensive null checking                  │
│                                                      │
│ 🎯 ROOT CAUSE:                                      │
│ Function handles multiple responsibilities at       │
│ different abstraction levels (parsing, validation,  │
│ building result).                                   │
│                                                      │
│ Impact: HIGH (4 issues) | Complexity: MODERATE      │
│ Priority: #1 CRITICAL                               │
└─────────────────────────────────────────────────────┘

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PRIORITIZED FIX ORDER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Priority #1: pkg/parser.go:45 (4 issues, HIGH impact)
Priority #2: pkg/validator.go:23 (3 issues, HIGH impact)
Priority #3: pkg/handler.go:67 (2 issues, MEDIUM impact)

Isolated issues: 6 (fix individually)

Total fix targets: 3 overlapping groups + 6 isolated = 9 fixes

STATUS: ISSUES_FOUND
```
</example>

<example name="delta_report">
**Status**: CLEAN_STATE (after fix)

This is what the quality-analyzer agent returns in incremental mode:

```
═══════════════════════════════════════════════════════
QUALITY ANALYSIS DELTA REPORT
Mode: INCREMENTAL
Files re-analyzed: 1 (changed since last run)
═══════════════════════════════════════════════════════

📊 SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Tests: ✅ PASS (coverage: 89% ↑)
Linter: ✅ PASS (0 errors)
Review: ✅ CLEAN (0 findings)

✅ Fixed: 4 issues from pkg/parser.go:45
⚠️ Remaining: 0 issues
🆕 New: 0 issues introduced

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RESOLUTION DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ FIXED:
  pkg/parser.go:45 | Linter | Cognitive complexity (was 18, now 8)
  pkg/parser.go:45 | Linter | Function length (was 58, now 25)
  pkg/parser.go:45 | Review | Mixed abstraction levels (resolved)
  pkg/parser.go:45 | Review | Defensive null checking (resolved)

STATUS: CLEAN_STATE ✅
Ready to proceed with next fix or move to documentation phase.
```
</example>
</example_reports>

<commit_readiness_template>
**Use for**: Phase 5 summary output

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
</commit_readiness_template>

<next_steps>
<step name="feature_complete">
→ Invoke @documentation skill to create feature docs
</step>

<step name="more_work_needed">
→ Run @linter-driven-development again for next commit
</step>

<step name="broader_issues_found">
→ Create new task to address technical debt
</step>
</next_steps>
