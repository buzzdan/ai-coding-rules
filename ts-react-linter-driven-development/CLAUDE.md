# TypeScript + React Linter-Driven Development

## Automatic Workflow Enforcement

**IMPORTANT**: When this plugin is enabled, ALL code changes must follow the linter-driven development workflow.

### For ANY Code Change (Features, Bug Fixes, Refactors)

**ALWAYS invoke `@linter-driven-development` skill** for code changes that will result in a commit:

1. **Before writing code**: If design decisions are needed, the workflow will invoke `@component-designing`
2. **During implementation**: Follow `@testing` principles (React Testing Library)
3. **After implementation**: The workflow automatically:
   - Runs all quality checks (TypeScript, ESLint, Prettier, Stylelint)
   - Invokes `@refactoring` if complexity issues found
   - Runs `@pre-commit-review` for design validation
   - Ensures iterative verification (runs checks twice)

### Mandatory Quality Gates

Every code change MUST pass:
- [ ] TypeScript compilation: 0 errors
- [ ] ESLint: 0 errors, 0 warnings in changed files
- [ ] Prettier: All changed files formatted
- [ ] Tests: All passing, coverage targets met

### Critical Rule: No Linter Disabling

**NEVER add linter disabling comments to changed files without explicit user approval:**
- `eslint-disable`, `eslint-disable-next-line`, `eslint-disable-line`
- `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck`
- `stylelint-disable`

If a linter rule fails:
1. Fix through proper refactoring (use `@refactoring` patterns)
2. If truly unfixable, ASK USER for explicit approval before disabling
3. When approved: Add a comment explaining WHY the rule is disabled

### Workflow Phases

```
Phase 1: Design (@component-designing) - if new abstractions needed
Phase 2: Implementation + Tests (@testing principles)
Phase 3: Linter Loop - run checks, fix issues, repeat until clean
Phase 4: Pre-Commit Review (@pre-commit-review) - advisory
Phase 5: Commit Ready - all checks pass, user decides on advisory findings
```

### Iterative Verification

After final changes, run quality checks at least TWICE: take the necessary check commands from project's package.json

Both runs must pass clean before completing.

### When User Requests Code Changes

1. Detect package manager (yarn.lock, package-lock.json, pnpm-lock.yaml)
2. Detect available scripts from package.json
3. Follow the linter-driven-development workflow
4. Present commit-ready summary with any advisory findings
5. Let user decide on advisory findings (commit as-is or fix first)

### Available Skills

- `@linter-driven-development` - META ORCHESTRATOR (use for all code changes)
- `@component-designing` - Component and type design
- `@testing` - Testing principles (React Testing Library)
- `@refactoring` - Complexity reduction patterns
- `@pre-commit-review` - Design validation (advisory)
- `@documentation` - Feature documentation (after feature complete)
