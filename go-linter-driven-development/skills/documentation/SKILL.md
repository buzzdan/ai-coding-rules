# Feature Documentation

Creates comprehensive feature documentation for humans and AI to use for
future bug resolution, feature extensions, and codebase understanding.

## When to Use
- After a complete feature is implemented (may span multiple commits)
- When adding significant new functionality to the codebase
- NOT for: individual commits, bug fixes, minor refactors

## Purpose
Generate documentation that helps:
- **Humans**: Understand what the feature does and how to use it
- **AI**: Context for future bug fixes and feature extensions
- **Team**: Onboarding and knowledge sharing

This is NOT a changelog - it's an introduction to the feature.

## Workflow

### 1. Understand Feature Scope
- Review all commits related to the feature
- Identify all modified/new files
- Understand the problem being solved
- Map out integration points with existing system

### 2. Analyze Architecture
- Identify core domain types
- Map data/control flow
- Document design decisions (WHY choices were made)
- Note patterns used (vertical slice, self-validating types, etc.)

### 3. Generate Documentation Artifacts

**Primary: Feature Documentation** (`docs/[feature-name].md`)
- Problem & solution: What problem does this solve?
- Architecture: How does it work?
- Usage examples: How do I use it?
- Integration: How does it fit into the system?

**Secondary: Code Comments**
- Update package godoc to reflect feature's role
- Add godoc to key types explaining their purpose
- Create testable examples (Example_* functions) when helpful

### 4. Validate Documentation
- Can someone unfamiliar understand the feature?
- Can AI use this for bug fixes without reading all code?
- Are design decisions clearly explained?
- Are integration points documented?

## Documentation Template

```markdown
# [Feature Name]

## Problem & Solution
**Problem**: [What user/system problem does this solve?]

**Solution**: [High-level approach taken]

## Architecture

### Core Types
- `TypeName` - [Purpose, why it exists, key responsibility]
- `AnotherType` - [Purpose, why it exists, key responsibility]

### Design Decisions
- **Why [Decision]**: [Rationale - connects to coding principles]
  - Example: "UserID is a custom type (not string) to avoid primitive obsession and ensure validation"
- **Why [Pattern]**: [Rationale]
  - Example: "Vertical slice structure groups all user logic together for easier maintenance"

### Data Flow
```
[Step-by-step flow diagram or description]
Input → Validation → Processing → Storage → Output
```

### Integration Points
- **Consumed by**: [What uses this feature]
- **Depends on**: [What this feature uses]
- **Events/Hooks**: [If applicable]

## Usage

### Basic Usage
```go
// Common case example
package main

func example() {
    // Real, runnable code
}
```

### Advanced Scenarios
```go
// Complex case example
package main

func advancedExample() {
    // Real, runnable code showing edge cases
}
```

## Testing Strategy
- **Unit Tests**: [What's covered, approach]
- **Integration Tests**: [What's covered, approach]
- **Coverage**: [Percentage and rationale]

## Future Considerations
- [Known limitations]
- [Potential extensions]
- [Related features that might be built on this]

## References
- [Related packages]
- [External documentation]
- [Design patterns used]
```

## Code Comment Guidelines

**Package-Level Documentation:**
```go
// Package [name] provides [high-level purpose].
//
// [2-3 sentences about what problem this solves and how]
//
// Core types:
//   - Type1: [Purpose]
//   - Type2: [Purpose]
//
// Example usage:
//   [Simple example showing typical usage]
//
// Design notes:
//   - [Key design decision]
//   - [Why certain patterns were used]
package name
```

**Type-Level Documentation:**
```go
// TypeName represents [domain concept].
//
// [Explain why this type exists - design decision]
// [Explain validation rules if self-validating]
// [Explain thread-safety if relevant]
//
// Example:
//   id, err := NewUserID("usr_123")
//   if err != nil {
//       // handle validation error
//   }
type TypeName struct {
    // ...
}
```

**Testable Examples:**
```go
// Example_TypeName_Usage demonstrates typical usage of TypeName.
func Example_TypeName_Usage() {
    id, _ := NewUserID("usr_123")
    fmt.Println(id)
    // Output: usr_123
}

// Example_TypeName_Validation shows validation behavior.
func Example_TypeName_Validation() {
    _, err := NewUserID("")
    fmt.Println(err != nil)
    // Output: true
}
```

## Output Format

After generating documentation:

```
📚 FEATURE DOCUMENTATION COMPLETE

Feature: [Feature Name]

Generated Artifacts:
✅ docs/[feature-name].md (created)
✅ Package godoc updated in [package]/[file].go
✅ Type documentation for:
   - TypeName1 ([file]:line)
   - TypeName2 ([file]:line)
✅ Testable examples:
   - Example_TypeName1_Usage
   - Example_TypeName2_Validation

Documentation covers:
- Problem & Solution overview
- Architecture with design decisions
- Core types: [list]
- Data flow diagram
- Integration points: [list]
- Usage examples (basic + advanced)
- Testing strategy
- Future considerations

📝 Next Steps:
1. Review docs/[feature-name].md for accuracy
2. Run `go test` to verify testable examples execute correctly
3. Consider: Does this help future you/AI understand the feature?

Would you like to:
1. Commit documentation as-is
2. Refine specific sections
3. Add more examples
4. Add testable examples to code
```

## Key Principles

**Documentation is NOT:**
- A changelog of commits
- Implementation details without context
- API reference without explanation
- Generated automatically without understanding

**Documentation IS:**
- Explaining WHY decisions were made
- Providing context for future changes
- Showing how pieces fit together
- Helping both humans and AI understand intent

**AI-Friendly Documentation:**
When AI tools read this documentation for bug fixes or extensions:
- They should understand the problem domain
- They should know which types are central
- They should understand design constraints
- They should see how it integrates with the system

See reference.md for complete documentation checklist and examples.
