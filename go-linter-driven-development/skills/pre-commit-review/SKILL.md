---
name: pre-commit-review
description: ADVISORY validation of code against design principles that linters cannot enforce. Use after linter passes and tests pass to validate design quality. Categorizes findings as Design Debt, Readability Debt, or Polish Opportunities. Does NOT block commits.
---

# Pre-Commit Design Review

ADVISORY validation of code against design principles that linters cannot enforce.
Categorizes findings as Design Debt, Readability Debt, or Polish Opportunities.

## When to Use
- Automatically invoked by @linter-driven-development (Phase 4)
- Manually before committing (to validate design quality)
- After linter passes and tests pass

## What This Reviews
- **NOT code correctness** (tests verify that)
- **NOT syntax/style** (linter enforces that)
- **YES design principles** (primitive obsession, abstraction, architecture)
- **YES maintainability** (readability, storifying, self-validation)

## Review Scope

**Primary Scope**: Changed code in commit
- All modified lines
- All new files
- Specific focus on design principle adherence

**Secondary Scope**: Context around changes
- Entire files containing modifications
- Flag patterns/issues outside commit scope
- Suggest broader refactoring opportunities

## Finding Categories (Debt-Based)

### 🔴 Design Debt
**Will cause pain when extending/modifying code**

Violations:
- Primitive obsession (string IDs, int ports without types)
- Wrong architecture (horizontal layers vs vertical slices)
- Non-self-validating types (validation outside constructor)
- Missing error context (errors.New instead of fmt.Errorf)

Impact: Future changes will require more work and introduce bugs

### 🟡 Readability Debt
**Makes code harder to understand and work with**

Violations:
- Mixed abstraction levels (story + implementation details)
- Functions not storified (unclear flow)
- Defensive nil checks (should be in constructor)
- Generic naming (utils, common, data, manager)

Impact: Team members (and AI) will struggle to understand intent

### 🟢 Polish Opportunities
**Minor improvements for consistency**

Violations:
- Non-idiomatic naming
- Missing comments on complex logic
- Opportunities for minor refactoring

Impact: Low, but keeps codebase clean and consistent

## Review Workflow

### 1. Analyze Commit Scope
```bash
# Identify what changed
git diff --cached --name-only

# For each file, get changed lines
git diff --cached --unified=3 [file]
```

### 2. Check Against Design Principles
For each changed line/block, validate:
- [ ] Primitive obsession check (reference.md #1)
- [ ] Storifying check (reference.md #2)
- [ ] Self-validating types check (reference.md #3)
- [ ] Abstraction levels check (reference.md #4)
- [ ] Architecture check (reference.md #5)
- [ ] Naming check (reference.md #6)
- [ ] Testing approach check (reference.md #7)

### 3. Scan Broader Context
Review entire files containing changes:
- Are there similar violations outside commit scope?
- Would fixing require broader refactoring?
- Is there a pattern worth addressing holistically?

### 4. Categorize Findings
Assign each violation to debt category:
- Design Debt (🔴): Type safety, architecture, validation
- Readability Debt (🟡): Abstraction, naming, clarity
- Polish (🟢): Minor improvements

### 5. Generate Advisory Report
For each finding:
- **Location**: file:line
- **Issue**: Specific violation with current code
- **Better**: Suggested improvement with example
- **Why**: Impact explanation (connects to maintenance/understanding)
- **Fix**: Which skill to use (@code-designing, @refactoring, etc.)

## Output Format

See linter-driven-development workflow for integrated output.

Key elements:
- Commit scope summary
- Findings grouped by category (🔴 🟡 🟢)
- Specific line numbers and code examples
- Broader context observations
- Actionable next steps

## Advisory Nature

**This review does NOT block commits.**

Purpose:
- ✅ Provide visibility into design quality
- ✅ Offer concrete improvement suggestions
- ✅ Help maintain coding principles
- ✅ Guide refactoring decisions

User decides:
- Commit as-is (accept debt knowingly)
- Fix critical debt before commit
- Fix all debt before commit
- Expand scope to broader refactor

## Integration with Other Skills

When findings suggest deeper work:
- **Design Debt** → often needs @code-designing skill
- **Readability Debt** → often needs @refactoring skill
- **Architecture issues** → may need @code-designing + @refactoring

See reference.md for complete design principles checklist.
