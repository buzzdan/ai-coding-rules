# TypeScript + React Linter-Driven Development

A comprehensive set of TypeScript + React coding principles and Claude Code skills for building clean, maintainable, accessible applications using **linter-driven development** with ESLint, TypeScript, Prettier, and SonarJS.

## What's Inside

### Six Specialized Skills

1. **linter-driven-development** - Meta-orchestrator for complete workflow (design → test → lint → review → commit)
2. **component-designing** - Component and type design, preventing primitive obsession
3. **testing** - Jest + React Testing Library principles and patterns
4. **refactoring** - SonarJS-driven refactoring strategies for complexity reduction
5. **pre-commit-review** - Design validation with integrated accessibility checks (advisory)
6. **documentation** - Storybook stories, JSDoc comments, and feature documentation

## Installation

### Prerequisites
- [Claude Code](https://claude.ai/code) installed
- Node.js and npm/yarn
- TypeScript + React development environment

### Install the Plugin

**Step 1: Add the marketplace**
```
/plugin marketplace add buzzdan/ai-coding-rules
```

**Step 2: Install the plugin**
```
/plugin install ts-react-linter-driven-development@ai-coding-rules
```

**Verify installation:**
```
/plugin list
```
Should show: `ts-react-linter-driven-development (enabled)`

That's it! All skills are now available:
- `@linter-driven-development`
- `@component-designing`
- `@testing`
- `@refactoring`
- `@pre-commit-review`
- `@documentation`

## Skills Overview

### 🎯 Meta-Orchestrator

#### `@linter-driven-development`
**The complete workflow orchestrator**

Manages the entire development cycle:
- **Phase 1**: Design (invokes `@component-designing` if needed)
- **Phase 2**: Implementation (applies `@testing` principles)
- **Phase 3**: Linter loop (runs ESLint/tsc/Prettier/Stylelint, invokes `@refactoring` if fails)
- **Phase 4**: Pre-commit review (invokes `@pre-commit-review` with a11y checks)
- **Phase 5**: Commit ready

**Use when:** Implementing any feature, bug fix, or refactor that should result in a commit.

**Quality Tools**:
- TypeScript compiler (`tsc`)
- ESLint with SonarJS plugin (complexity metrics)
- Prettier (formatting)
- Stylelint (CSS/SCSS)

**Complexity Thresholds** (SonarJS):
- Cognitive Complexity: max 15
- Cyclomatic Complexity: max 10
- Expression Complexity: max 5
- Max Function Length: 200 lines
- Max File Length: 600 lines
- Nesting Level: max 4

### 🎨 Individual Skills

#### `@component-designing`
**Component and type design**

Helps you:
- Design component composition patterns (presentational vs container)
- Prevent primitive obsession (Zod schemas, branded types)
- Plan feature-based architecture (not technical layers)
- Create custom hooks for reusable logic
- Design context for shared state

**Use when:** Planning new features or identifying need for new abstractions.

**Key Concepts**:
- Feature-based structure: `src/features/[feature]/`
- Branded types: `type UserId = Brand<string, 'UserId'>`
- Zod schemas: Runtime validation with type inference
- Custom hooks: Extract reusable logic
- Context: Only when needed (3+ component levels)

#### `@testing`
**Testing principles with Jest + React Testing Library**

Guides you on:
- Testing user behavior, not implementation details
- Accessible queries (getByRole, getByLabelText)
- MSW (Mock Service Worker) for realistic API mocking
- Real implementations over mocks
- Table-driven tests with test.each()
- Coverage strategies (100% for pure components/hooks)

**Use when:** Writing tests or clarifying testing approach.

**Key Patterns**:
- Query priority: getByRole > getByLabelText > getByText > getByTestId
- User interactions: user-event library
- Async testing: waitFor, findBy (not arbitrary timeouts)
- Hook testing: renderHook from @testing-library/react

#### `@refactoring`
**Linter-driven refactoring patterns**

Provides patterns for:
- Extract custom hook (move logic out of components)
- Extract component (break down large components)
- Early returns / guard clauses (reduce nesting)
- Simplify complex conditions (extract to variables/functions)
- Extract unstable nested components
- Simplify hook dependencies

**Use when:** ESLint fails with SonarJS complexity issues or code feels complex.

**Triggers**:
- `sonarjs/cognitive-complexity` (max: 15)
- `sonarjs/cyclomatic-complexity` (max: 10)
- `sonarjs/expression-complexity` (max: 5)
- `sonarjs/max-lines-per-function` (max: 200)
- `react/no-unstable-nested-components`
- `react-hooks/exhaustive-deps`

#### `@pre-commit-review`
**Design validation with integrated accessibility (advisory)**

Validates code against design principles:
- 🔴 **Design Debt** - Will cause pain when extending (primitive obsession, prop drilling, missing error boundaries)
- 🟡 **Readability Debt** - Hard to understand now (mixed abstractions, complex conditions, god components)
- 🟢 **Polish Opportunities** - Minor improvements (missing JSDoc, a11y enhancements, type improvements)

**Integrated Accessibility Checks**:
- Semantic HTML (button, form, nav, headings)
- ARIA attributes (labels, roles, descriptions)
- Keyboard navigation (focus, tab order, escape)
- Color and contrast (sufficient contrast, not color-only)
- Screen reader support (announcements, live regions)

Reviews entire commit + broader file context.

**Use when:** Before committing (automatically invoked by meta-orchestrator).

**Important**: This is **ADVISORY** - never blocks commits. User decides whether to fix findings.

#### `@documentation`
**Comprehensive feature documentation**

Creates documentation for:
- Storybook stories (visual component documentation)
- JSDoc comments (inline code documentation)
- Feature docs (problem, solution, architecture, design decisions)
- Usage examples (basic + advanced)
- Testing strategy and accessibility features

**Use when:** After completing a feature (may span multiple commits).

**Generates**:
- `.stories.tsx` files for components
- JSDoc comments for types, hooks, complex functions
- `docs/features/[feature].md` for architectural documentation

## Usage

### Complete Workflow (Recommended)

Use the meta-orchestrator for automatic workflow management:

```
You: "Implement user authentication using @linter-driven-development"

Claude:
Phase 1: Designs Email, UserId types with Zod schemas (@component-designing)
Phase 2: Implements with tests using Jest + RTL (@testing principles)
Phase 3: Runs quality checks:
  - npm run typecheck (TypeScript)
  - npm run lintcheck (ESLint with SonarJS)
  - npm run formatcheck (Prettier)
  - npm run stylecheck (Stylelint)
  If fails → refactors using patterns (@refactoring)
  Loops until all pass
Phase 4: Reviews design and accessibility (@pre-commit-review)
Phase 5: Presents commit-ready summary with findings
```

**Review Findings Format**:
```
⚠️  PRE-COMMIT REVIEW FINDINGS

🔴 DESIGN DEBT (2 findings) - Recommended to fix:
- Primitive obsession: email validation inline (use Zod schema)
- Missing error boundary: async operations can fail silently

🟡 READABILITY DEBT (3 findings) - Consider fixing:
- Mixed abstractions: validation logic mixed with UI
- Complex condition: hard to understand intent
- Missing hook extraction: logic should be in custom hook

🟢 POLISH OPPORTUNITIES (4 findings) - Optional:
- Missing JSDoc: public types should have documentation
- Accessibility: form could use aria-describedby
- Keyboard navigation: add Escape key handler
- Type improvement: use discriminated union for states

📝 BROADER CONTEXT:
Similar validation patterns in RegisterForm and ProfileForm.
Consider extracting to shared useFormValidation hook.

Would you like to:
1. Commit as-is (accept debt)
2. Fix design debt (🔴), then commit
3. Fix design + readability (🔴 + 🟡), then commit
4. Fix all findings (🔴 🟡 🟢), then commit
5. Refactor broader scope (address validation patterns)
```

### Individual Skills

Invoke skills independently when needed:

```
"Use @component-designing to plan types for payment processing"
"Use @testing to structure tests for UserService"
"Use @refactoring to reduce complexity in LoginForm"
"Use @pre-commit-review to validate this code"
"Use @documentation to document the auth feature"
```

## The Linter-Driven Development Flow

```
┌─────────────────────────────────────────────────────────────┐
│          TYPESCRIPT + REACT LINTER-DRIVEN DEVELOPMENT        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │   Design Phase   │
                    │(@component-       │
                    │  designing)       │
                    └──────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │ Implementation   │
                    │   + Testing      │
                    │  (@testing)      │
                    │  Jest + RTL      │
                    └──────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  Quality Checks  │
                    │ - TypeScript     │
                    │ - ESLint+SonarJS │
                    │ - Prettier       │
                    │ - Stylelint      │
                    └──────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
                ✅ Pass            ❌ Fail
                    │                   │
                    │         ┌──────────────────┐
                    │         │   Refactoring    │
                    │         │  (@refactoring)  │
                    │         │  SonarJS-driven  │
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
                    │  + Accessibility │
                    └──────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  Advisory Report │
                    │  🔴 Design Debt  │
                    │  🟡 Readability  │
                    │  🟢 Polish       │
                    │  + A11y Checks   │
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
          │ - Storybook      │          │
          │ - JSDoc          │          │
          │ - Feature Docs   │          │
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
- **Prevent primitive obsession** - Use Zod schemas and branded types (Email, UserId)
- **Feature-based architecture** - Group by feature (`src/features/auth/`), not technical layer
- **Component composition** - Presentational vs container, avoid prop drilling
- **Custom hooks** - Extract reusable logic, single responsibility
- **Context sparingly** - Only when needed (3+ component levels)

### Testing Principles
- **Test user behavior** - What users see and do, not implementation
- **Accessible queries** - getByRole, getByLabelText (best for accessibility)
- **Real implementations** - MSW for APIs, avoid heavy mocking
- **Table-driven tests** - test.each() for multiple scenarios
- **Coverage targets** - 100% for pure components/hooks, integration tests for containers

### Refactoring Principles
- **Linter-driven** - Let SonarJS complexity metrics guide refactoring
- **Extract early** - Custom hooks, components, helper functions
- **Early returns** - Reduce nesting (max 2 levels)
- **Simplify conditions** - Extract complex expressions to variables/functions

### Accessibility Principles
- **Semantic HTML** - Use correct elements (button, form, nav)
- **ARIA when needed** - Labels, roles, descriptions
- **Keyboard navigation** - All interactive elements accessible
- **Announce changes** - aria-live for dynamic content
- **Color + text** - Never rely on color alone

## Required npm Scripts

The linter-driven-development skill expects these scripts in your `package.json`:

### Option 1: Separate Check/Fix Commands (Recommended)
```json
{
  "scripts": {
    "typecheck": "tsc --noEmit",
    "lintcheck": "eslint .",
    "formatcheck": "prettier --check .",
    "stylecheck": "stylelint '**/*.scss'",
    "lint": "eslint . --fix",
    "format": "prettier --write .",
    "stylefix": "stylelint '**/*.scss' --fix",
    "test": "jest",
    "storybook": "storybook dev -p 6006",
    "build-storybook": "storybook build"
  }
}
```

### Option 2: Combined Commands
```json
{
  "scripts": {
    "checkall": "tsc --noEmit && eslint . && prettier --check . && stylelint '**/*.scss'",
    "fix": "eslint . --fix && prettier --write . && stylelint '**/*.scss' --fix",
    "test": "jest",
    "storybook": "storybook dev -p 6006"
  }
}
```

## Required ESLint Configuration

Install SonarJS plugin for complexity metrics:

```bash
npm install --save-dev eslint-plugin-sonarjs
```

**eslint.config.mjs** (ESLint v9):
```javascript
import sonarjs from 'eslint-plugin-sonarjs'
import tseslint from 'typescript-eslint'

export default tseslint.config(
  {
    extends: [
      ...tseslint.configs.recommendedTypeChecked,
      sonarjs.configs.recommended
    ],
    rules: {
      // Complexity thresholds
      'sonarjs/cognitive-complexity': ['error', 15],
      'sonarjs/cyclomatic-complexity': ['error', { threshold: 10 }],
      'sonarjs/expression-complexity': ['error', { max: 5 }],
      'sonarjs/max-lines-per-function': ['error', { maximum: 200 }],
      'sonarjs/max-lines': ['error', { maximum: 600 }],
      'sonarjs/nested-control-flow': ['warn', { maximumNestingLevel: 4 }]
    }
  }
)
```

## Best Practices

### 1. Start with the Meta-Orchestrator
For any non-trivial work, use `@linter-driven-development`:

```
"Implement shopping cart with @linter-driven-development"
```

### 2. Trust the Advisory Review
The `@pre-commit-review` skill provides **advisory** feedback, not blocking:

- 🔴 **Design Debt** - Strongly recommended to fix (will cause pain later)
- 🟡 **Readability Debt** - Consider fixing (harder to understand)
- 🟢 **Polish** - Optional improvements

You decide whether to apply fixes or accept the debt knowingly.

### 3. Use Accessibility Checks
Accessibility is integrated into pre-commit review:
- Semantic HTML validation
- ARIA attribute checking
- Keyboard navigation verification
- Screen reader support assessment

### 4. Don't Skip Documentation
After completing a feature, use `@documentation`:

```
"Document the user authentication feature using @documentation"
```

Creates:
- Storybook stories for visual documentation
- JSDoc comments for inline documentation
- `docs/features/authentication.md` for architecture

### 5. Use Skills Individually When Needed
Don't always need the full orchestrator:

```
# Quick design review before coding
"Use @component-designing to plan components for this feature"

# Check if tests are structured correctly
"Use @testing to review my test structure"

# Get refactoring suggestions
"Use @refactoring to suggest improvements for this component"
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
/plugin install ts-react-linter-driven-development@ai-coding-rules
```

**Updates:**
```
/plugin update ts-react-linter-driven-development@ai-coding-rules
```

### For Skill Maintainers

**Development Workflow:**

1. **Clone the repository:**
```bash
cd ~/dev
git clone https://github.com/buzzdan/ai-coding-rules.git
```

2. **Edit skills:**
```bash
cd ai-coding-rules/ts-react-linter-driven-development/skills
# Edit SKILL.md, reference.md files in any skill directory
```

3. **Test changes locally:**
```bash
cd ~/dev
claude

# Add local marketplace
/plugin marketplace add ./ai-coding-rules

# Install development version
/plugin install ts-react-linter-driven-development@ai-coding-rules
```

After making changes:
```
# Uninstall
/plugin uninstall ts-react-linter-driven-development@ai-coding-rules

# Reinstall to test
/plugin install ts-react-linter-driven-development@ai-coding-rules
```

4. **Commit and push:**
```bash
git add ts-react-linter-driven-development/
git commit -m "Improve refactoring patterns"
git push origin main
```

## Examples

### Example 1: Complete Feature Implementation

```
You: "Implement user profile editing with @linter-driven-development"

Claude:
📋 Phase 1: Design
- Creating types: UserId, Email, DisplayName (Zod schemas)
- Planning feature structure: src/features/profile/
- Components: ProfileForm (presentational), ProfileContainer (container)
- Hooks: useProfile (data fetching), useUpdateProfile (mutations)

📋 Phase 2: Implementation
- Writing tests with Jest + RTL
- Testing user interactions with user-event
- MSW for API mocking
- Achieving 95% coverage

📋 Phase 3: Quality Checks
- TypeScript: ✅ Passed
- ESLint: ❌ Failed (cognitive complexity 18 in ProfileForm)
- Applying @refactoring: Extract validation to useProfileValidation hook
- Re-running: ✅ All passed

📋 Phase 4: Pre-Commit Review
⚠️  4 findings:

🔴 Design Debt (1):
- profile/ProfileForm.tsx:67 - Primitive obsession for phone number
  Use PhoneNumberSchema with country code validation

🟡 Readability Debt (2):
- profile/ProfileForm.tsx:120 - Mixed abstractions in handleSubmit
  Extract validation logic to custom hook
- profile/useProfile.ts:45 - Complex useEffect dependencies
  Simplify with useMemo

🟢 Polish (1):
- profile/types.ts:15 - Missing JSDoc for DisplayName type
- profile/ProfileForm.tsx:89 - Accessibility: Add aria-describedby for hints

📝 BROADER CONTEXT:
Similar validation in SettingsForm. Consider shared validation hooks.

Would you like to:
1. Commit as-is
2. Fix design debt (🔴)
3. Fix design + readability (🔴 + 🟡)
4. Fix all (🔴 🟡 🟢)
5. Refactor validation across features

You: "3 - fix design and readability"

Claude: [Applies fixes, re-runs checks, presents updated summary]
```

## Troubleshooting

### Plugin not showing up
```
/plugin list
# If not listed:
/plugin marketplace add buzzdan/ai-coding-rules
/plugin install ts-react-linter-driven-development@ai-coding-rules
```

### Skills not available
```
/plugin list
# Verify enabled, if disabled:
/plugin
# Select plugin and choose "Enable"
```

### Linter commands not found
Ensure your `package.json` has the required scripts. See "Required npm Scripts" section above.

## Contributing

### Adding New Patterns
1. Edit appropriate skill's `reference.md`
2. Add examples to `examples.md` if applicable
3. Commit and push

### Creating New Skills
1. Create directory in `skills/`
2. Add `SKILL.md` (required) with YAML frontmatter
3. Add `reference.md` (optional) - detailed principles
4. Add `examples.md` (optional) - before/after examples
5. Update this README

## License

MIT

## Acknowledgments

Built for linter-driven development with TypeScript + React.
Optimized for use with [Claude Code](https://claude.ai/code).
Complements the [go-linter-driven-development](../go-linter-driven-development) plugin.
