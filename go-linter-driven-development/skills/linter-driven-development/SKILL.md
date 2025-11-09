---
name: linter-driven-development
description: Orchestrates a complete code implementation workflow - design, test, lint, refactor, review, and commit. Use for any new features, bug fixes, or refactors to ensure clean code with tests and design validation
---

# Linter-Driven Development Workflow

META ORCHESTRATOR for implementation workflow: design → test → lint → refactor → review → commit.
Use for any commit: features, bug fixes, refactors.

## When to Use
- Implementing any code change that should result in a commit
- Need automatic workflow management with quality gates
- Want to ensure: clean code + tests + linting + design validation

## Prerequisites - must have a linter command to run automatically
- find the project linter command in the project's docs like README.md/CLAUDE.md
  - if command not found in the project docs, you will need to look it up yourself:
  - look into the projects admin tasks like Makefile/Taskfile.yaml/package.json etc...
  - prefer a linter command with autofix capability like a command that runs golangci-lint run --fix
  - if no such command is found, run the linter command manually
  - if none of the above works, ask the user how to run the linter command.
  - when found: add it to the projects admin tasks like Makefile/Taskfile.yaml and then the project's docs like README.md/CLAUDE.md so it can be run automatically in the future.

## Workflow Phases

### Phase 1: Design
- for any new types/functions/major changes needed → invoke @code-designing skill
- when in plan mode, invoke @code-designing skill with plan mode flag
- Output: Type design plan with domain types

### Phase 2: Implementation
- invoke @code-designing skill for writing code
- invoke @testing skill for writing any tests
- Aim for 100% coverage on new leaf types or value objects (its ok to have dependencies on other leaf types, but always isolated, encapsulated, and tested independently)

### Phase 3: Linter Loop (automatically)
- run the linter command (prerequisites must be met)
- if failures detected:
  - interpret failures (complexity, maintainability, etc.)
  - invoke @refactoring skill to fix
  - re-run linter
  - repeat until linter passes clean

### Phase 4: Review Loop (automatically)
- Invoke @pre-commit-review skill
- Review validates design principles (not code correctness)
- Categorized findings: Design Debt / Readability Debt / Polish Opportunities
- If issues found in broader file context, flag for potential refactor
- itertate over the findings and invoke the @refactoring skill to fix the issues
- invoke Phase 3 (linter loop) until clean
- repeat until clean

### Phase 5: Commit Ready
- Linter passes ✅
- Tests pass with target coverage ✅
- Design review complete (findings fixed) ✅
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
