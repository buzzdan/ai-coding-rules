# Linter-Driven Development Reference (TypeScript + React)

## Overview

The linter-driven development workflow ensures code quality through automated tooling and design validation. This orchestrator manages the complete lifecycle from design to commit-ready code.

## Quality Tool Stack

### 1. TypeScript Compiler (`tsc`)
**Command**: `npm run typecheck`
**Purpose**: Type safety validation
**Can auto-fix**: No
**Failure resolution**: Manual type fixes or refactoring

### 2. ESLint
**Command**:
- Check: `npm run lintcheck`
- Fix: `npm run lint`

**Purpose**: Code quality, style, and complexity analysis
**Plugins used**:
- `eslint-plugin-sonarjs` - Complexity metrics (THE KEY PLUGIN)
- `typescript-eslint` - TypeScript-aware linting
- `eslint-plugin-react` - React best practices
- `eslint-plugin-react-hooks` - Hooks rules enforcement
- `eslint-plugin-jsx-a11y` - Accessibility rules
- `eslint-plugin-import` - Import/export management
- `eslint-plugin-unused-imports` - Remove dead code
- `eslint-plugin-simple-import-sort` - Auto-sort imports
- `eslint-plugin-promise` - Async/await best practices
- `eslint-plugin-security` - Security vulnerabilities

**Can auto-fix**: Many rules (formatting, imports, simple violations)
**Requires refactoring**: Complexity rules, design issues

### 3. Prettier
**Command**:
- Check: `npm run formatcheck`
- Fix: `npm run format`

**Purpose**: Code formatting consistency
**Can auto-fix**: Always (100% auto-fixable)

### 4. Stylelint
**Command**:
- Check: `npm run stylecheck`
- Fix: `npm run stylefix`

**Purpose**: SCSS/CSS linting
**Can auto-fix**: Most rules

## Workflow Phases in Detail

### Phase 1: Design

**Trigger**: New components, custom hooks, major architectural changes

**Actions**:
1. Invoke @component-designing skill
2. Answer design questions:
   - Component composition strategy?
   - State management approach?
   - Custom hooks needed?
   - Type definitions required?
3. Receive design plan with:
   - Component structure
   - Props interfaces
   - Custom hooks
   - Type definitions
   - File organization

**Output**: Design document ready for implementation

### Phase 2: Implementation + Testing

**Testing principles** (from @testing skill):
- Write tests for public API only
- Use React Testing Library patterns
- Test user behavior, not implementation
- Use MSW for API mocking (real HTTP)
- Avoid `waitFor` with arbitrary delays
- Achieve 100% coverage on leaf components/hooks (no dependencies on other types)
- Integration tests for orchestrating components (test interactions and composition)

**Implementation approach**:
- Parallel development (test + code together)
- Focus on behavior validation
- Use real implementations over mocks
- Follow component composition patterns
- Push business logic into leaf types for better testability

### Phase 3: Linter Loop

This is the core quality gate with multiple sub-checks:

#### Step 1: Type Checking
```bash
npm run typecheck
```
**Checks**: TypeScript compilation, type safety
**Failures**: Type errors, missing types, type mismatches
**Resolution**:
- Fix types manually
- Add type assertions where needed
- Use type guards for narrowing
- Cannot proceed if failing

#### Step 2: ESLint Check
```bash
npm run lintcheck
```
**Checks**: Code quality, complexity, React rules, hooks rules, a11y
**Failures**: See "ESLint Failure Categories" below
**Resolution**:
- Auto-fix: `npm run lint`
- If auto-fix insufficient → manual fixes or invoke @refactoring

#### Step 3: Prettier Check
```bash
npm run formatcheck
```
**Checks**: Code formatting consistency
**Failures**: Inconsistent formatting
**Resolution**: Always auto-fix with `npm run format`

#### Step 4: Stylelint Check
```bash
npm run stylecheck
```
**Checks**: SCSS/CSS quality and consistency
**Failures**: Style violations, naming issues
**Resolution**: Auto-fix with `npm run stylefix`, some manual fixes

#### Loop Behavior
```
Run all checks → Any fail? → Run auto-fixes → Re-run checks
                       ↓
                    Still failing?
                       ↓
              Complexity/design issues?
                       ↓
              Invoke @refactoring
                       ↓
                  Re-run checks
                       ↓
                Loop until pass
```

### Phase 4: Pre-Commit Review (Advisory)

**Always invoked**, even if linter passes.

**Purpose**: Validate design principles that linters cannot enforce

**Scope**:
- **Primary**: All changed code in current commit
- **Secondary**: Broader file context (flags patterns for future refactoring)

**Categories**:
- 🔴 **Design Debt**: Will cause pain when extending code
  - Primitive obsession (string IDs, unvalidated inputs)
  - Prop drilling (state passed through 3+ levels)
  - Tight coupling
  - Missing error boundaries
  - Non-self-validating types

- 🟡 **Readability Debt**: Hard to understand and work with
  - Mixed abstraction levels
  - Complex nested logic
  - Inline styles or logic
  - Poor naming
  - Missing component extraction

- 🟢 **Polish Opportunities**: Minor improvements
  - Missing JSDoc
  - Accessibility enhancements
  - Type refinements
  - Better naming

**Output**: Advisory report with specific line references and fix suggestions

**User Decision Points**:
1. Commit as-is (accept debt)
2. Fix design debt (🔴) - recommended
3. Fix design + readability (🔴 + 🟡)
4. Fix all (🔴 🟡 🟢)
5. Expand scope (refactor related code)

### Phase 5: Commit Ready

**Checklist**:
- ✅ Type checking passes
- ✅ ESLint passes
- ✅ Prettier passes
- ✅ Stylelint passes
- ✅ Tests pass (100% coverage on leaf types, integration tests on orchestrating components)
- ✅ Design review complete (advisory)

**Output**:
- Commit readiness summary
- Suggested commit message
- List of modified/added files
- Coverage report
- Design review findings
- User decision prompt

## Coverage Targets

Follow @testing skill principles for coverage strategy:

- **Leaf types** (pure logic, no external dependencies): 100% unit test coverage
- **Orchestrating types** (coordinate pieces, call external systems): Integration tests

See **testing/reference.md** for:
- Detailed coverage targets explanation
- Examples of leaf vs orchestrating types
- Testing approach for each type
- Architectural benefits

## ESLint Failure Categories

### Category 1: Auto-Fixable (npm run lint)
These are fixed automatically:
- Unused imports (`unused-imports/no-unused-imports`)
- Import sorting (`simple-import-sort/imports`)
- Missing semicolons, quotes, spacing (handled by Prettier)
- Simple style violations
- Arrow function simplification (`arrow-body-style`)

**Action**: Run `npm run lint` → Re-run checks → Continue

### Category 2: Requires Manual Fix
These need developer intervention but are straightforward:
- `@typescript-eslint/no-explicit-any` - Replace any with proper types
- `no-console` - Remove or replace with proper logging
- `react/jsx-key` - Add key props to list items
- `react-hooks/exhaustive-deps` - Fix hook dependencies
- Type-related issues

**Action**: Fix issues manually → Re-run checks → Continue

### Category 3: Requires Refactoring (invoke @refactoring)
These indicate design or complexity problems:
- `sonarjs/cognitive-complexity` (max: 15)
- `sonarjs/cyclomatic-complexity` (max: 10)
- `sonarjs/expression-complexity` (max: 5)
- `sonarjs/max-lines-per-function` (max: 200)
- `sonarjs/max-lines` (max: 600)
- `sonarjs/nested-control-flow` (max: 4 levels)
- `react/no-unstable-nested-components` - Extract components
- `react/no-multi-comp` - Split into multiple files

**Action**: Invoke @refactoring skill → Apply patterns (storifying, extract hooks/functions, early returns, simplify conditionals) → Re-run checks → Continue

## Complexity Thresholds Explained

### Cognitive Complexity (max: 15)
**What it measures**: How difficult is it to understand the code?
**Increments for**: Nested structures, breaks in linear flow, recursion
**Why it matters**: High cognitive load → more bugs, harder maintenance

**How to fix**: Invoke @refactoring skill which applies **storifying** - making code read like a story at single abstraction level. See refactoring/reference.md for detailed techniques and examples.

**Example violation**:
```tsx
// Cognitive complexity: 18 (too high!)
function validateUser(user: User): ValidationResult {
  if (user) {  // +1
    if (user.email) {  // +2 (nested)
      if (isValidEmail(user.email)) {  // +3 (nested)
        if (user.age >= 18) {  // +4 (nested)
          if (user.country === 'US') {  // +5 (nested)
            return { valid: true }
          } else {  // +1
            return { valid: false, reason: 'Not in US' }
          }
        }
      } else {  // +1
        return { valid: false, reason: 'Invalid email' }
      }
    }
  }
  return { valid: false, reason: 'Missing user' }
}
```

**How to fix**: Invoke @refactoring skill to storify with early returns (see refactoring/reference.md)

### Cyclomatic Complexity (max: 10)
**What it measures**: Number of independent paths through code
**Increments for**: if, else, case, &&, ||, while, for, catch
**Why it matters**: More paths → more test cases needed, higher bug risk

**Fix strategies**: Extract functions, use polymorphism, simplify conditionals

### Expression Complexity (max: 5)
**What it measures**: Number of operators in a single expression
**Increments for**: &&, ||, ternary operators
**Why it matters**: Hard to read, error-prone

**Example violation**:
```tsx
// Expression complexity: 6 (too high!)
const isValid = user && user.email && isValidEmail(user.email) && user.age >= 18 && user.country === 'US' && !user.banned
```

**Fix**: Extract to variables or validation function

### Storifying Pattern

When cognitive complexity is high, invoke @refactoring skill which applies storifying patterns (making code read like a story at single abstraction level).

See **refactoring/reference.md** for:
- Detailed storifying explanation with examples
- TypeScript and React examples
- When and how to apply storifying
- Step-by-step storifying process

## Integration with Other Skills

### @component-designing
**When invoked**: Phase 1, if new components/major changes needed
**Input**: Feature requirements
**Output**: Component structure, props, hooks, types
**Next step**: Proceed to Phase 2 implementation

### @testing
**When applied**: Phase 2, during implementation
**Input**: Component/hook to test
**Output**: Test files with React Testing Library
**Principles**: User-centric testing, real implementations

### @refactoring
**When invoked**: Phase 3, when linter fails on complexity
**Input**: Failing component/function + linter error
**Output**: Refactored code that passes linter
**Patterns**: Storifying, extract hooks/functions, simplify logic, early returns, single abstraction levels

### @pre-commit-review
**When invoked**: Phase 4, always (advisory)
**Input**: All changed code + file context
**Output**: Design review findings (🔴 🟡 🟢)
**Decision**: User chooses whether to apply fixes

### @documentation
**When invoked**: After commit (feature complete)
**Input**: Implemented feature
**Output**: Storybook stories, JSDoc, feature docs
**Purpose**: Documentation for humans and AI

## Command Alternatives

Different projects may use different naming conventions:

### Option 1: Separate check/fix commands
```bash
# Checks (validation only)
npm run typecheck
npm run lintcheck
npm run formatcheck
npm run stylecheck

# Fixes (auto-fix where possible)
npm run lint
npm run format
npm run stylefix
```

### Option 2: Combined commands
```bash
# Check all quality gates
npm run checkall  # or npm run check

# Fix all auto-fixable issues
npm run fix
```

### Option 3: Task runner (if available)
```bash
# Using task runner (e.g., make, task)
task lint
task fix
```

**Plugin should detect** which commands are available from `package.json` scripts.

## Best Practices

### 1. Fail Fast, Fix Fast
- Run linter frequently during development
- Don't accumulate linter errors
- Fix auto-fixable issues immediately

### 2. Trust Complexity Metrics
- SonarJS complexity rules are calibrated well
- If it flags complexity → there's real complexity
- Refactor rather than disable

### 3. Respect Advisory Review
- Design debt compounds over time
- Fix 🔴 before committing when possible
- Track accepted debt in tickets

### 4. Test After Refactoring
- Complexity fixes can introduce bugs
- Re-run tests after @refactoring
- Verify behavior unchanged

### 5. Commit Granularly
- Small, focused commits
- Each commit passes all gates
- Easy to review and revert

## Troubleshooting

### "Type errors won't go away"
- TypeScript errors require manual fixes
- Consider if types are correct (not the code)
- Use type guards for narrowing
- Add type assertions as last resort

### "ESLint keeps failing after auto-fix"
- Auto-fix only handles simple rules
- Complexity rules need refactoring
- Invoke @refactoring skill
- May need architectural changes

### "Linter passes but review finds issues"
- Expected! Linters can't enforce design principles
- Review catches: primitive obsession, coupling, architecture
- User decides whether to fix

### "Too many findings in review"
- Common for legacy code
- Fix incrementally (design debt first)
- Consider broader refactor ticket
- Don't let perfect be enemy of good

## Related Files
- For design patterns: See @component-designing/reference.md
- For testing strategies: See @testing/reference.md
- For refactoring patterns: See @refactoring/reference.md
- For review principles: See @pre-commit-review/reference.md
