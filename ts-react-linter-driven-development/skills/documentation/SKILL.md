---
name: documentation
description: Generate comprehensive feature documentation including Storybook stories, JSDoc comments, and feature guides. Use after completing a feature (may span multiple commits). Creates documentation for humans and AI to understand features, usage patterns, and design decisions.
---

# Documentation (TypeScript + React)

Generate comprehensive documentation for features, components, and hooks.

## When to Use
- After completing a feature (may span multiple commits)
- When a component/hook needs usage documentation
- When design decisions need recording
- For public/shared components and hooks

## Documentation Types

### 1. Storybook Stories (Component Documentation)
**Purpose**: Visual documentation of component usage and variants

**Creates**: `.stories.tsx` files alongside components

### 2. JSDoc Comments (Code Documentation)
**Purpose**: Inline documentation for types, props, complex functions

**Location**: In source files (`.ts`, `.tsx`)

### 3. Feature Documentation (Architectural Documentation)
**Purpose**: WHY decisions were made, HOW feature works, WHAT to extend

**Creates**: `docs/features/[feature-name].md`

## Workflow

### 1. Identify Documentation Needs

Ask:
- Is this a reusable component? → Storybook story
- Is this a custom hook? → JSDoc + usage example
- Is this a complete feature? → Feature documentation
- Are types/props complex? → JSDoc comments

### 2. Create Storybook Stories

**For each component**, create stories showing:
- Default state
- All variants/props
- Interactive states
- Edge cases (loading, error, empty)

**Example**:
```typescript
// src/components/Button/Button.stories.tsx
import type { Meta, StoryObj } from '@storybook/react'
import { Button } from './Button'

const meta: Meta<typeof Button> = {
  title: 'Components/Button',
  component: Button,
  parameters: {
    layout: 'centered'
  },
  tags: ['autodocs'],
  argTypes: {
    variant: {
      control: 'select',
      options: ['primary', 'secondary', 'danger']
    }
  }
}

export default meta
type Story = StoryObj<typeof Button>

// Default story
export const Primary: Story = {
  args: {
    label: 'Button',
    variant: 'primary',
    onClick: () => alert('clicked')
  }
}

// Variants
export const Secondary: Story = {
  args: {
    ...Primary.args,
    variant: 'secondary'
  }
}

export const Danger: Story = {
  args: {
    ...Primary.args,
    variant: 'danger'
  }
}

// States
export const Disabled: Story = {
  args: {
    ...Primary.args,
    isDisabled: true
  }
}

export const Loading: Story = {
  args: {
    ...Primary.args,
    isLoading: true
  }
}

// Interactive example
export const WithIcon: Story = {
  args: {
    ...Primary.args,
    icon: <IconCheck />
  }
}
```

### 3. Add JSDoc Comments

**For public types and interfaces**:
```typescript
/**
 * Props for the Button component.
 *
 * @example
 * ```tsx
 * <Button
 *   label="Click me"
 *   variant="primary"
 *   onClick={() => console.log('clicked')}
 * />
 * ```
 */
export interface ButtonProps {
  /** The text to display on the button */
  label: string

  /** The visual style variant of the button */
  variant?: 'primary' | 'secondary' | 'danger'

  /** Callback fired when the button is clicked */
  onClick: () => void

  /** If true, the button will be disabled */
  isDisabled?: boolean

  /** If true, the button will show a loading spinner */
  isLoading?: boolean
}
```

**For custom hooks**:
```typescript
/**
 * Custom hook for managing user authentication state.
 *
 * Handles login, logout, and persisting auth state to localStorage.
 * Automatically refreshes token when it expires.
 *
 * @param options - Configuration options for authentication
 * @returns Authentication state and methods
 *
 * @example
 * ```tsx
 * function LoginForm() {
 *   const { login, isLoading, error } = useAuth()
 *
 *   const handleSubmit = async (email: string, password: string) => {
 *     await login(email, password)
 *   }
 *
 *   return <Form onSubmit={handleSubmit} isLoading={isLoading} error={error} />
 * }
 * ```
 */
export function useAuth(options?: AuthOptions): UseAuthReturn {
  // Implementation
}
```

**For complex types**:
```typescript
/**
 * Represents the state of an asynchronous operation.
 *
 * Uses discriminated union to ensure invalid states are impossible
 * (e.g., cannot have both data and error simultaneously).
 *
 * @template T - The type of data returned on success
 *
 * @example
 * ```typescript
 * const [state, setState] = useState<AsyncState<User>>({ status: 'idle' })
 *
 * // Type narrowing works automatically
 * if (state.status === 'success') {
 *   console.log(state.data.name) // state.data is available and typed
 * }
 * ```
 */
export type AsyncState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: Error }
```

### 4. Create Feature Documentation

**For completed features**, create `docs/features/[feature-name].md`:

**Template**:
```markdown
# Feature: [Feature Name]

## Overview
Brief description of what the feature does and why it exists.

## Problem
What problem does this feature solve? What was the pain point?

## Solution
How does this feature solve the problem? What approach was taken?

## Architecture

### Components
- **ComponentName**: Purpose and responsibility
- **AnotherComponent**: Purpose and responsibility

### Hooks
- **useFeatureHook**: What it does and why it's separate

### Context
- **FeatureContext**: What state it manages and why context was needed

### Types
- **KeyType**: What it represents and why it's a custom type

## Key Design Decisions

### 1. [Decision Title]
**Decision**: What was decided
**Rationale**: Why this approach was chosen
**Alternatives**: What other approaches were considered
**Trade-offs**: What we gained and what we gave up

### 2. [Another Decision]
...

## Usage

### Basic Usage
```typescript
// Simple example showing most common use case
```

### Advanced Usage
```typescript
// Example showing advanced features or edge cases
```

### Integration
How this feature integrates with other parts of the application.

## API Reference

### Components

#### ComponentName
Props:
- `propName` (Type): Description

Events:
- `onEvent`: When it fires and what it provides

#### AnotherComponent
...

### Hooks

#### useFeatureHook
Parameters:
- `param` (Type): Description

Returns:
- `returnValue` (Type): Description

### Types

#### TypeName
```typescript
type TypeName = ...
```

Description of when and how to use this type.

## Testing Strategy

### Unit Tests
- What is tested at the unit level (pure components, hooks)
- Coverage expectations (100% for leaf components)

### Integration Tests
- What user flows are tested
- How mocking is handled (MSW for APIs)

## Accessibility

### Compliance
- WCAG level compliance (A, AA, AAA)
- What accessibility features are implemented

### Keyboard Navigation
- What keyboard shortcuts are supported
- How tab order works

### Screen Reader Support
- What ARIA attributes are used
- What announcements are made

## Performance Considerations

### Optimizations
- What performance optimizations are implemented
- Use of memo, useMemo, useCallback

### Bundle Impact
- Approximate bundle size contribution
- Any lazy loading or code splitting

## Known Limitations

### Current Limitations
- What doesn't work yet
- What edge cases aren't handled

### Future Enhancements
- What could be improved
- What features could be added

## Troubleshooting

### Common Issues

#### Issue: [Problem Description]
**Symptom**: What users will see
**Cause**: Why this happens
**Solution**: How to fix it

## Related Features
- Links to related documentation
- Dependencies on other features
- Features that depend on this

## Migration Guide
(If replacing existing functionality)

### Before
```typescript
// Old way
```

### After
```typescript
// New way
```

### Breaking Changes
- What changed
- How to update code

## Changelog
- v1.1.0 (2024-01-15): Added support for...
- v1.0.0 (2024-01-01): Initial implementation
```

## Output Format

After generating documentation:

```
📚 DOCUMENTATION GENERATED

Feature: User Authentication

Generated Files:
✅ Storybook Stories (3 components)
   - src/features/auth/components/LoginForm.stories.tsx
   - src/features/auth/components/RegisterForm.stories.tsx
   - src/features/auth/components/PasswordInput.stories.tsx

✅ JSDoc Comments Added
   - src/features/auth/hooks/useAuth.ts (hook documentation)
   - src/features/auth/types.ts (type definitions)
   - src/features/auth/context/AuthContext.tsx (context API)

✅ Feature Documentation
   - docs/features/authentication.md (complete guide)

📖 Documentation includes:
   - Problem/solution overview
   - Architecture and design decisions
   - Usage examples (basic + advanced)
   - API reference (components, hooks, types)
   - Testing strategy
   - Accessibility features
   - Performance considerations
   - Troubleshooting guide

🎯 Next Steps:
1. Review generated Storybook stories locally: npm run storybook
2. Review feature documentation: docs/features/authentication.md
3. Update any project-specific references or links
4. Commit documentation with feature code

📝 Maintenance:
- Update Storybook stories when component props change
- Update JSDoc when APIs change
- Update feature docs when design decisions change
- Keep examples working (they're testable!)
```

## Documentation Principles

### For Humans AND AI

Documentation serves two audiences:
1. **Human developers**: Need to understand and extend code
2. **AI assistants**: Need context to help debug and extend features

Write documentation that helps both audiences understand:
- **WHY** decisions were made (context for future changes)
- **HOW** the feature works (architecture and flow)
- **WHAT** can be extended (integration points)

### Show, Don't Tell

Prefer code examples over prose descriptions:

**❌ Bad**:
```
The Button component accepts a variant prop that can be primary,
secondary, or danger, and will style the button accordingly.
```

**✅ Good**:
```typescript
<Button variant="primary" label="Save" />
<Button variant="secondary" label="Cancel" />
<Button variant="danger" label="Delete" />
```

### Keep Examples Executable

Storybook stories and JSDoc examples should be real, working code that compiles and runs.

### Document Design Decisions

Most important: **WHY** decisions were made.

**❌ Bad**:
```
// Uses context for state management
```

**✅ Good**:
```
/**
 * Uses AuthContext for state management instead of prop drilling.
 *
 * Decision: Context chosen because auth state is needed in 10+
 * components across different nesting levels (nav, profile, settings,
 * protected routes). Prop drilling would be unmaintainable.
 *
 * Alternative considered: Redux - overkill for single feature state
 */
```

## When to Document

### Always Document
- Public/shared components
- Custom hooks (except trivial ones)
- Complex types (discriminated unions, branded types)
- Completed features (spanning multiple commits)

### Consider Documenting
- Complex utility functions
- Non-obvious algorithms
- Performance-critical code
- Edge cases and workarounds

### Don't Over-Document
- Trivial functions (self-explanatory)
- Implementation details (private functions)
- Obvious code (const user = getUser())

## Best Practices

### Storybook
- One story file per component
- Show all variants
- Include interactive controls
- Document props with argTypes
- Add accessibility checks (a11y addon)

### JSDoc
- Use `@param`, `@returns`, `@example` tags
- Include examples showing typical usage
- Document complex types inline
- Link related types with `@see`

### Feature Docs
- Start with problem/solution
- Include architecture diagrams (mermaid)
- Provide working code examples
- Document WHY, not just WHAT
- Keep updated as feature evolves

## Tools

### Storybook Commands
```bash
# Run Storybook locally
npm run storybook

# Build static Storybook
npm run build-storybook

# Test stories (interaction testing)
npm run test-storybook
```

### TypeDoc (Alternative to JSDoc)
```bash
# Generate API documentation from TypeScript
npx typedoc --entryPoints src/index.ts
```

## Key Principles

See reference.md for detailed principles:
- Document WHY, not just WHAT
- Show working code examples
- Keep docs close to code
- Update docs with code changes
- Test examples (Storybook)
- Document for humans AND AI
- Focus on usage, not implementation

See reference.md for complete documentation templates and examples.
