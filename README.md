# AI Coding Rules

A comprehensive set of Go coding principles and Claude Code skills for building clean, maintainable, testable systems using **linter-driven development**.

## What's Inside

### 📋 `coding_rules.md`
Complete Go coding principles covering:
- Type design (primitive obsession prevention, self-validating types)
- Architecture (vertical slices)
- Testing strategies (table-driven, real implementations over mocks)
- Refactoring patterns
- Anti-patterns to avoid

### 🛠️ `skills/` - Claude Code Skills
Six specialized skills that work together to automate clean code practices:

1. **linter-driven-development** - Meta-orchestrator for complete workflow
2. **code-designing** - Domain type design and architecture planning
3. **testing** - Testing principles and patterns
4. **refactoring** - Linter-driven refactoring strategies
5. **pre-commit-review** - Design validation (advisory)
6. **documentation** - Feature documentation generation

## Installation

### Prerequisites
- [Claude Code](https://claude.ai/code) installed
- Go development environment

### Install the Plugin

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

That's it! All skills are now available:
- `@linter-driven-development`
- `@code-designing`
- `@testing`
- `@refactoring`
- `@pre-commit-review`
- `@documentation`

### Optional: Load in CLAUDE.md

For automatic context loading:
```markdown
# Your Project CLAUDE.md

## Automatic Go Coding Context
When working on Go code, ALWAYS read @ai-coding-rules/coding_rules.md first.
```

## Skills Overview

### 🎯 Meta-Orchestrator

#### `@linter-driven-development`
**The complete workflow orchestrator**

Manages the entire development cycle:
- Phase 1: Design (invokes `@code-designing` if needed)
- Phase 2: Implementation (applies `@testing` principles)
- Phase 3: Linter loop (runs linter, invokes `@refactoring` if fails)
- Phase 4: Pre-commit review (invokes `@pre-commit-review`)
- Phase 5: Commit ready

**Use when:** Implementing any feature, bug fix, or refactor that should result in a commit.

### 🎨 Individual Skills

#### `@code-designing`
**Domain type design and architecture planning**

Helps you:
- Design self-validating types
- Prevent primitive obsession
- Plan vertical slice architecture
- Create proper type hierarchies

**Use when:** Planning new features or identifying need for new types.

#### `@testing`
**Testing principles and patterns**

Guides you on:
- Table-driven tests (cyclomatic complexity = 1)
- Testify suites (only for complex setup)
- Real implementations over mocks
- Synchronization without time.Sleep
- Coverage strategies (100% for leaf types)

**Use when:** Writing tests or clarifying testing approach.

#### `@refactoring`
**Linter-driven refactoring patterns**

Provides patterns for:
- Storifying (clarify abstraction levels)
- Extract type (fix primitive obsession)
- Early returns (reduce nesting)
- Switch extraction (categorize cases)
- Decision tree for complexity reduction

**Use when:** Linter fails or code feels complex.

#### `@pre-commit-review`
**Design validation (advisory)**

Validates code against design principles:
- 🔴 **Design Debt** - Will cause pain when extending
- 🟡 **Readability Debt** - Hard to understand now
- 🟢 **Polish Opportunities** - Minor improvements

Reviews entire commit + broader file context.

**Use when:** Before committing (automatically invoked by meta-orchestrator).

#### `@documentation`
**Feature documentation generation**

Creates documentation for:
- Problem & solution overview
- Architecture with design decisions
- Usage examples (basic + advanced)
- Testing strategy
- Integration points

**Use when:** After completing a feature (may span multiple commits).

## Usage

### Complete Workflow (Recommended)

Use the meta-orchestrator for automatic workflow management:

```
You: "Implement user authentication using @linter-driven-development"

Claude:
1. Designs UserID, Email types (@code-designing)
2. Implements with tests (@testing principles)
3. Runs linter, refactors if needed (@refactoring)
4. Reviews design (@pre-commit-review)
5. Presents commit-ready summary with findings
```

You decide:
- Commit as-is
- Fix design debt (🔴)
- Fix design + readability debt (🔴 + 🟡)
- Fix all findings (🔴 🟡 🟢)
- Refactor broader scope

### Individual Skills

Invoke skills independently when needed:

```
"Use @code-designing to plan types for payment processing"
"Use @testing to structure tests for UserService"
"Use @refactoring to reduce complexity in HandleRequest"
"Use @pre-commit-review to validate this code"
"Use @documentation to document the auth feature"
```

## The Linter-Driven Development Flow

```
┌─────────────────────────────────────────────────────────────┐
│                   LINTER-DRIVEN DEVELOPMENT                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │   Design Phase   │
                    │  (@code-designing)│
                    └──────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │ Implementation   │
                    │   + Testing      │
                    │  (@testing)      │
                    └──────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  Run Linter      │
                    │ task lintwithfix │
                    └──────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
                ✅ Pass            ❌ Fail
                    │                   │
                    │         ┌──────────────────┐
                    │         │   Refactoring    │
                    │         │  (@refactoring)  │
                    │         └──────────────────┘
                    │                   │
                    │         ┌─────────┘
                    │         │ Loop until pass
                    │         │
                    └─────────┴─────────┐
                              │
                              ▼
                    ┌──────────────────┐
                    │  Pre-Commit      │
                    │     Review       │
                    │ (@pre-commit-    │
                    │    review)       │
                    └──────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  Advisory Report │
                    │  🔴 Design Debt  │
                    │  🟡 Readability  │
                    │  🟢 Polish       │
                    └──────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  User Decides    │
                    │  & Commits       │
                    └──────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │ Feature Complete?│
                    └──────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
                  Yes                  No
                    │                   │
                    ▼                   │
          ┌──────────────────┐          │
          │  Documentation   │          │
          │ (@documentation) │          │
          └──────────────────┘          │
                    │                   │
                    │         ┌─────────┘
                    │         │ Next commit
                    │         │
                    ▼         ▼
                  ┌─────────────┐
                  │    Done!    │
                  └─────────────┘
```

## Key Principles

### Design Principles
- **Prevent primitive obsession** - Use self-validating types (UserID, Email, Port)
- **Self-validating types** - Validate in constructor, trust in methods
- **Vertical slices** - Group by feature, not technical layer
- **Types around intent** - Design around behavior, not just shape
- **Leaf types** - Most logic in self-contained, testable types

### Testing Principles
- **Test public API only** - Use `pkg_test` package
- **Real implementations** - Avoid mocks, use in-memory implementations
- **Table-driven tests** - Cyclomatic complexity = 1 per test case
- **Testify suites** - Only for complex infrastructure setup
- **Coverage targets** - 100% for leaf types, integration tests for orchestrators

### Refactoring Principles
- **Linter-driven** - Let linter failures guide refactoring
- **Storifying** - Top-level functions read like stories
- **Extract types** - Move primitive logic to custom types
- **Early returns** - Reduce nesting (max 2 levels)
- **Functions < 50 LOC** - Break down large functions

## Best Practices

### 1. Start with the Meta-Orchestrator
For any non-trivial work, use `@linter-driven-development` to ensure you follow the complete workflow:

```
"Implement port configuration with validation using @linter-driven-development"
```

### 2. Trust the Advisory Review
The `@pre-commit-review` skill provides **advisory** feedback, not blocking. It categorizes findings:

- 🔴 **Design Debt** - Strongly recommended to fix (will cause pain later)
- 🟡 **Readability Debt** - Consider fixing (harder to understand)
- 🟢 **Polish** - Optional improvements

You decide whether to apply fixes or accept the debt knowingly.

### 3. Don't Skip Documentation
After completing a feature (spanning one or multiple commits), use `@documentation`:

```
"Document the user authentication feature using @documentation"
```

This creates docs/[feature].md with:
- Problem/solution overview
- Architecture decisions
- Usage examples
- Integration points

### 4. Iterate and Improve
The skills are living documents in your git repo:
- Found a better pattern? Update reference.md
- Need more examples? Add to examples.md
- Workflow needs adjustment? Edit SKILL.md

Commit, push, and everyone benefits.

### 5. Use Skills Individually When Needed
Don't always need the full orchestrator:

```
# Quick design review before coding
"Use @code-designing to plan types for this feature"

# Check if tests are structured correctly
"Use @testing to review my test structure"

# Get refactoring suggestions for complex function
"Use @refactoring to suggest improvements for this function"
```

## Team Setup

### For Team Members

**Standard Installation:**

1. Add the marketplace:
```
/plugin marketplace add buzzdan/ai-coding-rules
```

2. Install the plugin:
```
/plugin install go-linter-driven-development@ai-coding-rules
```

**Or** add to your project's `.claude/settings.json` for automatic team-wide marketplace availability:
```json
{
  "extraKnownMarketplaces": [
    "buzzdan/ai-coding-rules"
  ]
}
```

Then team members can:
```
/plugin marketplace add buzzdan/ai-coding-rules
/plugin install go-linter-driven-development@ai-coding-rules
```

**Updates:**
```
/plugin update go-linter-driven-development@ai-coding-rules
```

### For Skill Maintainers

**Development Workflow:**

1. **Clone the repository:**
```bash
cd ~/dev
git clone https://github.com/buzzdan/ai-coding-rules.git
cd ai-coding-rules
```

2. **Edit skills:**
```bash
cd go-linter-driven-development/skills
# Edit SKILL.md, reference.md, examples.md files in any skill directory
```

3. **Test changes locally:**
```bash
# Start Claude Code from parent directory
cd ~/dev
claude

# Add local marketplace
/plugin marketplace add ./ai-coding-rules

# Install your development version
/plugin install go-linter-driven-development@ai-coding-rules
```

After making changes:
```
# Uninstall current version
/plugin uninstall go-linter-driven-development@ai-coding-rules

# Reinstall to test changes
/plugin install go-linter-driven-development@ai-coding-rules
```

4. **Commit and push:**
```bash
cd ~/dev/ai-coding-rules
git add go-linter-driven-development/
git commit -m "Improve refactoring patterns in @refactoring skill"
git push origin main
```

5. **Team gets updates:**
Team members run:
```
/plugin update go-linter-driven-development@ai-coding-rules
```

## Debt-Based Review Categories

The `@pre-commit-review` skill uses **debt-based categories** (not "critical/important/nice-to-have") to reflect maintenance reality:

### 🔴 Design Debt
**Will cause pain when extending/modifying code**

Examples:
- Primitive obsession (string IDs, int ports)
- Wrong architecture (horizontal layers)
- Non-self-validating types
- Missing error context

**Impact:** Future changes require more work and risk bugs.

### 🟡 Readability Debt
**Makes code harder to understand and work with**

Examples:
- Mixed abstraction levels
- Functions not storified
- Defensive nil checks
- Generic naming (utils, common)

**Impact:** Team members (and AI) struggle to understand intent.

### 🟢 Polish Opportunities
**Minor improvements for consistency**

Examples:
- Non-idiomatic naming
- Missing comments
- Minor refactoring opportunities

**Impact:** Low, but keeps codebase clean.

## Examples

### Example 1: Complete Feature Implementation

```
You: "Implement user registration with email validation using @linter-driven-development"

Claude:
📋 Phase 1: Design
- Creating types: UserID, Email (self-validating)
- Planning vertical slice: user/user.go, user/service.go, user/repository.go

📋 Phase 2: Implementation
- Writing tests for UserID, Email constructors
- Implementing UserService with real in-memory repository
- Achieving 100% coverage on leaf types

📋 Phase 3: Linter
- Running: task lintwithfix
- ✅ Passed (0 issues)

📋 Phase 4: Pre-Commit Review
⚠️  3 findings:
🔴 Design Debt (1):
   - user/service.go:67 - Session token should be SessionToken type

🟡 Readability Debt (1):
   - user/service.go:89 - Mixed abstractions in CreateUser()

🟢 Polish (1):
   - user/repository.go:34 - Naming: SaveUser → Save

📝 Broader Context:
While reviewing user/service.go, noticed similar primitive obsession
in GetUserByEmail (line 120). Consider broader refactor.

Would you like to:
1. Commit as-is
2. Fix design debt (🔴)
3. Fix design + readability (🔴🟡)
4. Fix all (🔴🟡🟢)
5. Refactor entire file

You: "2 - fix design debt"

Claude: [Applies design debt fixes, re-runs linter, presents updated summary]
```

### Example 2: Individual Skill Usage

```
You: "Use @code-designing to plan types for payment processing"

Claude:
🎨 DESIGN PLAN

Core Domain Types:
✅ Amount (float64) - Self-validating, prevents negative amounts
✅ Currency (string) - Self-validating, ISO 4217 codes only
✅ PaymentMethod (string) - Enum: CreditCard, BankTransfer, etc.

Orchestrating Types:
✅ PaymentService - Coordinates payment operations
   Dependencies: Repository, Gateway, Notifier
   Methods: ProcessPayment, RefundPayment, GetStatus

Package Structure:
📁 payment/
  ├── amount.go       # Amount type
  ├── currency.go     # Currency type
  ├── method.go       # PaymentMethod enum
  ├── service.go      # PaymentService
  └── gateway.go      # Gateway interface

Design Decisions:
- Amount is custom type to prevent negative values and ensure precision
- Currency validation ensures only valid ISO codes
- Vertical slice keeps all payment logic together

Ready to implement?
```

## Troubleshooting

### Plugin not showing up
```
# Check installed plugins
/plugin list

# If not listed, install it
/plugin marketplace add buzzdan/ai-coding-rules
/plugin install go-linter-driven-development@ai-coding-rules
```

### Skills not available after installation
```
# Verify plugin is enabled
/plugin list

# If disabled, enable it
/plugin
# Select "go-linter-driven-development" and choose "Enable"
```

### Plugin update not working
```
# Try uninstalling and reinstalling
/plugin uninstall go-linter-driven-development@ai-coding-rules
/plugin install go-linter-driven-development@ai-coding-rules
```

## Contributing

### Adding New Patterns
1. Edit appropriate skill's `reference.md`
2. Add examples to `examples.md` if applicable
3. Commit and push

### Creating New Skills
1. Create new directory in `skills/`
2. Add `SKILL.md` (required) - Describes when/how to use
3. Add `reference.md` (optional) - Detailed principles/patterns
4. Add `examples.md` (optional) - Before/after examples
5. Update this README with new skill description

### Testing Skills
Before committing skill changes:
1. Test in Claude Code with real code
2. Verify skill invocation works
3. Check that skill produces expected output
4. Ensure integration with other skills works

## License

[Add your license here]

## Acknowledgments

Built for linter-driven development with Go.
Optimized for use with [Claude Code](https://claude.ai/code).
