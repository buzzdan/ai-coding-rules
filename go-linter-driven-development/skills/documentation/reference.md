# Feature Documentation Reference

Complete guide for generating feature documentation that serves both humans and AI.

## Documentation Quality Checklist

### Problem & Solution Section
- [ ] Clear problem statement (what user/system pain point?)
- [ ] High-level solution approach
- [ ] Why this solution was chosen over alternatives

### Architecture Section
- [ ] All core types listed with their purpose
- [ ] Design decisions explained with rationale
- [ ] Connections to coding principles (primitive obsession prevention, vertical slice, etc.)
- [ ] Data flow diagram or clear description
- [ ] Integration points with existing system documented

### Usage Section
- [ ] Basic usage example with runnable code
- [ ] Advanced usage example showing edge cases
- [ ] Common patterns demonstrated
- [ ] Examples are copy-pasteable

### Testing Section
- [ ] Unit test approach explained
- [ ] Integration test approach explained
- [ ] Coverage metrics and rationale provided

### Future Considerations
- [ ] Known limitations documented
- [ ] Potential extensions noted
- [ ] Related features that could build on this mentioned

## Code Comments Checklist

### Package Documentation
- [ ] High-level purpose explained
- [ ] Problem domain described
- [ ] Core types listed with brief descriptions
- [ ] Simple usage example included
- [ ] Key design decisions noted

### Type Documentation
- [ ] Domain concept the type represents
- [ ] Why the type exists (design decision)
- [ ] Validation rules if self-validating
- [ ] Thread-safety guarantees if applicable
- [ ] Usage example for non-trivial types

### Testable Examples (Example_* functions)
- [ ] At least one Example_* for complex/core types
- [ ] Examples are runnable (not pseudocode)
- [ ] Examples show common use cases
- [ ] Output comments included for verification
- [ ] Examples should be in test files

## AI-Friendly Documentation Patterns

### For Bug Fixes
AI needs to know:
- What was the original problem this feature solved?
- What are the core invariants that must be maintained?
- What assumptions were made?
- What are the integration points?

**Example:**
```markdown
## Design Invariants
- UserID must always be non-empty after construction
- Email validation follows RFC 5322
- UserService assumes repository is never nil (validated in constructor)
- Password hashes use bcrypt with cost factor 12
```

### For Feature Extensions
AI needs to know:
- What patterns are established?
- Where are the natural extension points?
- What constraints must be maintained?

**Example:**
```markdown
## Extension Points
- **New validation rules**: Add to NewUserID constructor
- **New storage backends**: Implement Repository interface
- **New notification channels**: Add implementation of Notifier interface
- **New authentication methods**: Implement Authenticator interface
```

### For Understanding Data Flow
AI needs to see:
- Entry points (how is this triggered?)
- Key transformation steps (what happens in sequence?)
- Exit points (what are the possible outcomes?)

**Example:**
```markdown
## Data Flow
1. HTTP handler receives POST /users → CreateUserRequest
2. Request validation → NewUserID, NewEmail (self-validating types)
3. UserService.CreateUser → validates business rules
4. Repository.Save → persists to database
5. Notifier.SendWelcome → sends welcome email (async)
6. Returns: User struct or validation/business error
```

## Documentation Anti-Patterns

### ❌ Implementation Details Without Context
```markdown
## Implementation
The CreateUser function calls validateEmail and then repo.Save.
It returns an error if validation fails.
```
*Why bad?*: Describes WHAT code does without WHY

### ✅ Context-Rich Explanation
```markdown
## Design Decision: Validation Before Persistence
CreateUser validates email format before database operations to:
1. Fail fast - avoid unnecessary database round-trips
2. Provide clear error messages - users get immediate feedback
3. Maintain data quality - only valid emails in database

Email validation is separate from UserID validation because emails
may need external verification (MX record checks) in the future,
while UserIDs are purely format-based.
```

### ❌ Feature List Without Purpose
```markdown
## Components
- UserID type
- Email type
- UserService
- Repository interface
- Notifier interface
```
*Why bad?*: No explanation of relationships or rationale

### ✅ Purpose-Driven Structure
```markdown
## Architecture

### Type Safety Layer (Primitive Obsession Prevention)
- **UserID**: Self-validating identifier (prevents empty/malformed IDs)
- **Email**: Self-validating email (prevents invalid formats, RFC 5322)

These types ensure validation happens once at construction, not repeatedly
throughout the codebase.

### Business Logic Layer
- **UserService**: Orchestrates user operations (creation, authentication)
  - Depends on Repository for persistence
  - Depends on Notifier for communication
  - Contains no infrastructure code (pure business logic)

### Abstraction Layer (Dependency Inversion)
- **Repository interface**: Abstracts persistence (allows multiple backends)
- **Notifier interface**: Abstracts communication (email, SMS, push)

This vertical slice structure keeps all user logic contained in one package,
following the principle: "group by feature and role, not technical layer."
```

### ❌ Code Dump as "Example"
```markdown
## Usage
See user_test.go for usage examples.
```
*Why bad?*: Forces reader to hunt through test code

### ✅ Inline Runnable Examples
```markdown
## Basic Usage

Creating a new user with validated types:
```go
package main

import (
    "context"
    "fmt"
    "github.com/yourorg/project/user"
)

func main() {
    // Create validated types
    id, err := user.NewUserID("usr_12345")
    if err != nil {
        panic(err) // Invalid ID format
    }

    email, err := user.NewEmail("alice@example.com")
    if err != nil {
        panic(err) // Invalid email format
    }

    // Create user service
    repo := user.NewPostgresRepository(db)
    notifier := user.NewEmailNotifier(smtpConfig)
    svc, _ := user.NewUserService(repo, notifier)

    // Create user
    u := user.User{
        ID:    id,
        Email: email,
        Name:  "Alice",
    }

    err = svc.CreateUser(context.Background(), u)
    if err != nil {
        fmt.Printf("Failed to create user: %v\n", err)
    }
}
```

## Quality Gates

Before considering documentation complete, verify:

### Clarity Test
- Can someone unfamiliar with the code read this and understand the feature?
- Are design decisions explained, not just described?
- Is technical jargon explained or avoided?

### AI Test
- Can AI use this to fix a bug without reading all implementation code?
- Are integration points clearly documented?
- Are invariants and assumptions explicit?

### Maintenance Test
- If the feature needs extension, is it clear where to add code?
- Are patterns documented so new code matches existing style?
- Are limitations and future considerations noted?

### Example Test
- Can examples be copy-pasted and run with minimal setup?
- Do examples demonstrate real-world usage patterns?
- Are edge cases covered in advanced examples?

## Common Documentation Scenarios

### Scenario 1: New Domain Type
Document:
- Why this type exists (what primitive obsession does it prevent?)
- What it validates
- How to construct it
- Where it's used in the system

### Scenario 2: New Service/Orchestrator
Document:
- What business operations it provides
- What dependencies it requires (and why)
- How it fits into existing architecture
- Integration points with other services

### Scenario 3: New Integration Point
Document:
- What external system/service is integrated
- Why this integration exists
- How data flows in/out
- Error handling strategy
- Retry/fallback behavior

### Scenario 4: Refactored Architecture
Document:
- What problem the refactor solved
- What changed architecturally
- Why this approach was chosen
- Migration notes (if applicable)
- Before/after comparison

## Testable Examples Best Practices

### When to Add Example_* Functions
- Complex types with non-obvious usage
- Types with validation rules
- Common use case patterns
- Non-trivial workflows

### Example_* Function Structure
```go
// Example_TypeName_Scenario describes what this example demonstrates.
func Example_TypeName_Scenario() {
    // Setup (minimal)
    input := "example input"

    // Usage (the point of the example)
    result, err := SomeFunction(input)
    if err != nil {
        fmt.Printf("Error: %v\n", err)
        return
    }

    // Output (demonstrating result)
    fmt.Println(result)
    // Output: expected output
}
```

### Multiple Examples for Same Type
```go
// Example_UserID shows basic UserID creation.
func Example_UserID() {
    id, _ := user.NewUserID("usr_123")
    fmt.Println(id)
    // Output: usr_123
}

// Example_UserID_validation shows validation behavior.
func Example_UserID_validation() {
    _, err := user.NewUserID("")
    fmt.Println(err != nil)
    // Output: true
}

// Example_UserID_invalidFormat shows error handling.
func Example_UserID_invalidFormat() {
    _, err := user.NewUserID("invalid")
    if err != nil {
        fmt.Println("validation failed")
    }
    // Output: validation failed
}
```

## Documentation Location Strategy

### Feature Documentation
- Location: `docs/[feature-name].md`
- One file per major feature
- Name should match package/feature name

### Package Documentation
- Location: Package-level godoc in main `.go` file
- Example: `user/user.go` has package documentation

### Type Documentation
- Location: Godoc on type definition
- Keep close to the code

### Examples
- Location: Test files (`*_test.go`)
- Use `_test` package for external perspective
