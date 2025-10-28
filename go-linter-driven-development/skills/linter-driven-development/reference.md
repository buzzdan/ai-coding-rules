# Linter-Driven Development Reference

This meta-orchestrator skill coordinates other skills. See individual skill reference files for detailed principles:

## Phase-Specific References

### Phase 1: Design
See: **code-designing/reference.md**
- Type design principles
- Primitive obsession prevention
- Self-validating types
- Vertical slice architecture

### Phase 2: Implementation & Testing
See: **testing/reference.md**
- Testing principles
- Table-driven tests
- Testify suites
- Real implementations over mocks

### Phase 3: Linter & Refactoring
See: **refactoring/reference.md**
- Linter signal interpretation
- Refactoring patterns
- Complexity reduction strategies

### Phase 4: Pre-Commit Review
See: **pre-commit-review/reference.md**
- Design principles checklist
- Debt categorization
- Review process

## Linter Commands

### Primary Command
```bash
task lintwithfix
```
Runs:
1. `go vet` - Static analysis
2. `golangci-lint fmt` - Format code
3. `golangci-lint run --fix` - Lint with auto-fix

### Fallback (if no taskfile)
```bash
golangci-lint run --fix
```

### Configuration
- Config file: `.golangci.yaml` in project root
- Always use golangci-lint v2
- Reference: https://github.com/golangci/golangci-lint/blob/HEAD/.golangci.reference.yml

## Linter Failure Signals

### Cyclomatic Complexity
**Signal**: Function too complex (too many decision points)
**Action**: Extract functions, simplify logic flow
**Skill**: @refactoring

### Cognitive Complexity
**Signal**: Function hard to understand (nested logic, mixed abstractions)
**Action**: Storifying, extract helpers, clarify abstraction levels
**Skill**: @refactoring

### Maintainability Index
**Signal**: Code difficult to maintain
**Action**: Break into smaller pieces, improve naming, reduce coupling
**Skill**: @refactoring + potentially @code-designing

## Coverage Targets

### Leaf Types
- **Target**: 100% unit test coverage
- **Why**: Leaf types contain core logic, must be bulletproof
- **Test**: Only public API, use pkg_test package

### Orchestrating Types
- **Target**: Integration test coverage
- **Why**: Test seams between components
- **Test**: Can overlap with leaf type coverage

## Commit Readiness Criteria

All must be true:
- ✅ Linter passes with 0 issues
- ✅ Tests pass
- ✅ Target coverage achieved (100% for leaf types)
- ✅ Design review complete (advisory, but acknowledged)

## Next Steps After Commit

### Feature Complete?
→ Invoke @documentation skill to create feature docs

### More Work Needed?
→ Run @linter-driven-development again for next commit

### Found Broader Issues During Review?
→ Create new task to address technical debt
