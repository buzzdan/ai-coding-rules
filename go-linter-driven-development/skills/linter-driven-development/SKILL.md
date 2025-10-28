---
name: linter-driven-development
description: META ORCHESTRATOR for complete implementation workflow - design, test, lint, refactor, review, commit. Use for any code change that should result in a commit (features, bug fixes, refactors). Ensures clean code with tests, linting passes, and design validation.
---

# Linter-Driven Development Workflow

META ORCHESTRATOR for implementation workflow: design → test → lint → refactor → review → commit.
Use for any commit: features, bug fixes, refactors.

## When to Use
- Implementing any code change that should result in a commit
- Need automatic workflow management with quality gates
- Want to ensure: clean code + tests + linting + design validation

## Workflow Phases

### Phase 1: Design (if needed)
- If new types/major changes needed → invoke @code-designing skill
- Output: Type design plan with domain types

### Phase 2: Implementation
- Follow @testing skill principles
- Write tests + implementation in parallel (not necessarily test-first)
- Aim for 100% coverage on new leaf types

### Phase 3: Linter Loop
- Run `task lintwithfix` automatically
- If failures detected:
  - Interpret failures (complexity, maintainability, etc.)
  - Invoke @refactoring skill to fix
  - Re-run linter
- Repeat until linter passes clean

### Phase 4: Pre-Commit Design Review (ADVISORY)
- Invoke @pre-commit-review skill
- Review validates design principles (not code correctness)
- Categorized findings: Design Debt / Readability Debt / Polish Opportunities
- If issues found in broader file context, flag for potential refactor
- **User decides**: commit as-is, apply fixes, or expand scope

### Phase 5: Commit Ready
- Linter passes ✅
- Tests pass with target coverage ✅
- Design review complete (advisory) ✅
- Present summary + commit message suggestion

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
