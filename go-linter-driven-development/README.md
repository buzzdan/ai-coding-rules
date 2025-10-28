# Go Linter-Driven Development

Claude Code plugin for linter-driven development with Go.

## What's Included

Six specialized skills that work together:

1. **@linter-driven-development** - Meta-orchestrator for complete workflow
2. **@code-designing** - Domain type design and architecture planning
3. **@testing** - Testing principles and patterns
4. **@refactoring** - Linter-driven refactoring strategies
5. **@pre-commit-review** - Design validation (advisory)
6. **@documentation** - Feature documentation generation

## Why Linter-Driven Development?

### Code Written for Understanding, Not Just Execution

The philosophy: **If code takes more than 10-15 seconds to understand, it's too complex.**

Modern development involves two readers:
- **Humans** - Limited by working memory (4-7 items, Miller's Law)
- **AI** - Works on heuristics from clean, well-documented code

Clean, storified code with clear abstractions and documentation provides:
- **Lower cognitive load** → Faster human understanding
- **Better heuristics** → More accurate AI assistance

### The Three Pillars of Maintainability

Linter rules enforce objective quality standards:

**1. Cyclomatic Complexity ≤ 10**
- Counts independent execution paths through code
- Higher complexity = more places for bugs to hide
- Forces breaking down complex logic into testable units

**2. Cognitive Complexity ≤ 15**
- Measures human effort required to understand code
- Penalizes deeply nested structures and mixed abstractions
- Enforces "storified" functions that read like prose

**3. High Maintainability Index**
- Composite metric predicting long-term code health
- Reflects how easy code is to modify without breaking
- Studies show: maintenance costs grow exponentially with complexity

### How Linter Rules Drive Design

Beyond complexity metrics, linter rules enforce architectural decisions:

**`gochecknoglobals`** → Dependency injection instead of global state
**`gocognit`** → Extract functions, reduce nesting
**`gocyclo`** → Break switch statements into strategy patterns
**`funlen`** → Functions < 50 LOC, single responsibility
**`nestif`** → Max 2 nesting levels, use early returns

**The result**: Design decisions aren't subjective—they're driven by measurable quality metrics.

### Why This Matters

**For Humans:**
- Developers spend far more time reading code than writing it
- Lower complexity = faster onboarding, easier debugging, fewer errors
- Code reviews focus on design, not comprehension struggles

**For AI:**
- Clean abstractions provide better context for code generation
- Well-named types and functions improve AI suggestions
- Documentation and comments enhance AI understanding of intent

**For Teams:**
- Objective quality standards reduce bike-shedding
- Linter failures signal technical debt accumulation
- Consistent style across contributors

### The Workflow Philosophy

Instead of writing code then hoping it passes review, **let the linter guide refactoring**:

1. **Design** - Plan types around behavior (prevent primitive obsession)
2. **Implement** - Write tests, implement with full coverage
3. **Lint** - Run linter (cyclomatic, cognitive, maintainability checks)
4. **Refactor** - Let linter failures drive extraction into cleaner abstractions
5. **Review** - Validate design principles linters can't catch
6. **Commit** - Code is guaranteed maintainable by objective metrics

This plugin automates this workflow, ensuring every commit meets quality standards.

## Installation

**Step 1: Add the marketplace**
```
/plugin marketplace add buzzdan/ai-coding-rules
```

**Step 2: Install the plugin**
```
/plugin install go-linter-driven-development@ai-coding-rules
```

**Verify installation:**
```
/plugin list
```
Should show: `go-linter-driven-development (enabled)`

## Quick Start

### Complete Workflow
```
"Implement user authentication using @linter-driven-development"
```

This automatically:
1. Designs UserID, Email types (@code-designing)
2. Implements with tests (@testing principles)
3. Runs linter, refactors if needed (@refactoring)
4. Reviews design (@pre-commit-review)
5. Presents commit-ready summary

### Individual Skills
```
"Use @code-designing to plan types for payment processing"
"Use @testing to structure tests for UserService"
"Use @refactoring to reduce complexity in HandleRequest"
"Use @pre-commit-review to validate this code"
"Use @documentation to document the auth feature"
```

## The Workflow

```
Design → Implement → Lint → Refactor → Review → Commit
  ↓         ↓         ↓        ↓         ↓        ↓
@code-  @testing  linter  @refactor  @pre-   Decision
designing                            commit
                                     review
```

## Debt-Based Review Categories

- 🔴 **Design Debt** - Will cause pain when extending
- 🟡 **Readability Debt** - Hard to understand now
- 🟢 **Polish Opportunities** - Minor improvements

## Key Principles

### Design
- Prevent primitive obsession (use self-validating types)
- Vertical slices (group by feature, not layer)
- Types around intent and behavior

### Testing
- Test public API only (`pkg_test` package)
- Real implementations over mocks
- 100% coverage for leaf types

### Refactoring
- Linter-driven (let failures guide)
- Storifying (functions read like stories)
- Early returns (reduce nesting)

## Updating

```
/plugin update go-linter-driven-development@ai-coding-rules
```

Or update through the plugin menu:
```
/plugin
```
Select "go-linter-driven-development" and choose "Update"

## Uninstalling

```
/plugin
```
Select "go-linter-driven-development" and choose "Uninstall"

## Documentation

For complete documentation, see the [main repository](https://github.com/buzzdan/ai-coding-rules).

## Support

Issues and feature requests: [GitHub Issues](https://github.com/buzzdan/ai-coding-rules/issues)

## License

MIT
