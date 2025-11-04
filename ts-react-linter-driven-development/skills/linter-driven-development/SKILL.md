---
name: linter-driven-development
description: META ORCHESTRATOR for complete implementation workflow - design, test, lint, refactor, review, commit. Use for any code change that should result in a commit (features, bug fixes, refactors). Ensures clean code with tests, linting passes, and design validation.
---

# Linter-Driven Development Workflow (TypeScript + React)

META ORCHESTRATOR for implementation workflow: design → test → lint → refactor → review → commit.
Use for any commit: features, bug fixes, refactors.

## When to Use
- Implementing any code change that should result in a commit
- Need automatic workflow management with quality gates
- Want to ensure: clean code + tests + linting + design validation + accessibility

## Workflow Phases

### Phase 1: Design (if needed)
- If new components/types/major changes needed → invoke @component-designing skill
- Output: Component design plan with types, hooks, and structure

### Phase 2: Implementation
- Follow @testing skill principles (Jest + React Testing Library)
- Write tests + implementation in parallel (not necessarily test-first)
- Aim for 100% coverage on new leaf components/hooks (pure logic with no external dependencies)
  - Leaf types: Pure logic (can compose other leaf types), no API/DB/file system access
  - Orchestrating types: Coordinate leaf types and external systems, need integration tests
- Test from user perspective (public API only)

### Phase 3: Linter Loop
Run quality checks in this order:
1. **Type Check**: `npm run typecheck` (TypeScript compiler)
2. **Lint Check**: `npm run lintcheck` (ESLint validation)
3. **Format Check**: `npm run formatcheck` (Prettier validation)
4. **Style Check**: `npm run stylecheck` (Stylelint for SCSS)

If any failures detected:
- Run auto-fixes:
  - `npm run lint` (ESLint --fix)
  - `npm run format` (Prettier --write)
  - `npm run stylefix` (Stylelint --fix)
- Re-run quality checks
- If still failing (complexity, design issues):
  - Interpret failures (cognitive complexity, cyclomatic complexity, etc.)
  - Invoke @refactoring skill to fix (use storifying, extract functions/hooks, early returns)
  - Re-run checks
- Repeat until all checks pass clean

**Alternative**: If project has combined commands:
- Check: `npm run checkall` or `npm run check`
- Fix: `npm run fix`

### Phase 4: Pre-Commit Design Review (ADVISORY)
- Invoke @pre-commit-review skill
- Review validates design principles (not code correctness)
- Includes accessibility checks (ARIA, semantic HTML, keyboard nav)
- Categorized findings: Design Debt / Readability Debt / Polish Opportunities
- If issues found in broader file context, flag for potential refactor
- **User decides**: commit as-is, apply fixes, or expand scope

### Phase 5: Commit Ready
- Type checking passes ✅
- ESLint passes ✅
- Prettier passes ✅
- Stylelint passes ✅
- Tests pass with target coverage ✅
- Design review complete (advisory) ✅
- Present summary + commit message suggestion

## Output Format

```
📋 COMMIT READINESS SUMMARY

✅ Type Check: Passed (0 errors)
✅ ESLint: Passed (0 issues)
✅ Prettier: Passed (all files formatted)
✅ Stylelint: Passed (0 style issues)
✅ Tests: 92% coverage (3 leaf hooks at 100%, 1 orchestrating component, 18 test cases)
⚠️  Design Review: 3 findings (see below)

🎯 COMMIT SCOPE
Modified:
- src/features/auth/LoginForm.tsx (+65, -20 lines)
- src/features/auth/useAuth.ts (+30, -5 lines)

Added:
- src/features/auth/types.ts (new: UserId, Email types)
- src/features/auth/AuthContext.tsx (new context provider)

Tests:
- src/features/auth/LoginForm.test.tsx (+95 lines)
- src/features/auth/useAuth.test.ts (new)
- src/features/auth/types.test.ts (new)

⚠️  DESIGN REVIEW FINDINGS

🔴 DESIGN DEBT (Recommended to fix):
- src/features/auth/LoginForm.tsx:45 - Primitive obsession detected
  Current: function validateEmail(email: string): boolean
  Better:  Use Zod schema or branded Email type with validation
  Why: Type safety, validation guarantee, prevents invalid emails
  Fix: Use @component-designing to create self-validating Email type

- src/features/auth/useAuth.ts:78 - Prop drilling detected
  Auth state passed through 3+ component levels
  Why: Tight coupling, hard to maintain
  Fix: Extract AuthContext or use composition pattern

🟡 READABILITY DEBT (Consider fixing):
- src/features/auth/LoginForm.tsx:120 - Mixed abstraction levels
  Component mixes validation logic with UI rendering
  Why: Harder to understand and test independently
  Fix: Use @refactoring to extract custom hooks (useValidation)

- src/features/auth/LoginForm.tsx:88 - Cognitive complexity: 18 (max: 15)
  Nested conditionals for form validation
  Why: Hard to understand logic flow
  Fix: Use @refactoring to extract validation functions or use Zod

🟢 POLISH OPPORTUNITIES:
- src/features/auth/types.ts:12 - Missing JSDoc comments
  Public types should have documentation
- src/features/auth/LoginForm.tsx:45 - Consider semantic HTML
  Use <form> with proper ARIA labels for better accessibility
- src/features/auth/useAuth.ts:34 - Missing error boundaries
  Consider wrapping async operations with error handling

📝 BROADER CONTEXT:
While reviewing LoginForm.tsx, noticed similar validation patterns in
RegisterForm.tsx and ProfileForm.tsx (src/features/user/). Consider
extracting a shared validation hook or creating branded types for common
fields (Email, Username, Password) used across the application.

💡 SUGGESTED COMMIT MESSAGE
Add self-validating Email and UserId types to auth feature

- Introduce Email type with RFC 5322 validation using Zod
- Introduce UserId branded type for type safety
- Refactor LoginForm to use validated types
- Extract useAuth hook for auth state management
- Add AuthContext to eliminate prop drilling
- Achieve 92% test coverage with React Testing Library

Follows component composition principles and reduces primitive obsession.

────────────────────────────────────────

Would you like to:
1. Commit as-is (ignore design findings)
2. Fix design debt only (🔴), then commit
3. Fix design + readability debt (🔴 + 🟡), then commit
4. Fix all findings (🔴 🟡 🟢), then commit
5. Refactor broader scope (address validation patterns across features), then commit
```

## Complexity Thresholds (SonarJS)

These metrics trigger @refactoring when exceeded:
- **Cognitive Complexity**: max 15
- **Cyclomatic Complexity**: max 10
- **Expression Complexity**: max 5
- **Function Length**: max 200 lines
- **File Length**: max 600 lines
- **Nesting Level**: max 4

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
- @component-designing (Phase 1, if needed)
- @testing (Phase 2, principles applied)
- @refactoring (Phase 3, when linter fails on complexity)
- @pre-commit-review (Phase 4, always)

After committing, consider:
- If feature complete → invoke @documentation skill
- If more work needed → run this workflow again for next commit

## Common Linter Failures and Resolutions

### TypeScript Errors (npm run typecheck)
- Type mismatches → Fix types or add proper type guards
- Missing types → Add explicit types or interfaces
- Cannot fix automatically → Manual intervention required

### ESLint Failures (npm run lintcheck)
**Auto-fixable**:
- Import sorting (simple-import-sort)
- Unused imports (unused-imports)
- Formatting issues covered by Prettier
- Simple style violations

**Requires refactoring** (invoke @refactoring):
- Cognitive/cyclomatic complexity
- Max lines per function
- Expression complexity
- Nested control flow
- React hooks violations
- Component design issues

### Prettier Failures (npm run formatcheck)
- Always auto-fixable with `npm run format`
- No manual intervention needed

### Stylelint Failures (npm run stylecheck)
- Most auto-fixable with `npm run stylefix`
- Class naming violations may require manual fixes

## Best Practices

1. **Run checks frequently** during development
2. **Fix one complexity issue at a time** (don't batch refactoring)
3. **Trust the advisory review** (design debt causes future pain)
4. **Test after each refactoring** (ensure behavior unchanged)
5. **Commit frequently** (small, focused commits)
