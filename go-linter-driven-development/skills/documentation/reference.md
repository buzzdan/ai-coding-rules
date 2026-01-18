# Documentation Reference

Templates, checklists, examples, and guidelines for the documentation skill.

---

## Documentation Layers

Documentation exists at multiple levels, each serving different purposes:

| Layer | Location | Purpose | Updates When |
|-------|----------|---------|--------------|
| **System** | `docs/architecture.md` | Cross-component relationships, system-wide patterns | Major architectural changes |
| **Project** | `docs/README.md` | Project purpose, setup, structure overview | New features, setup changes |
| **Feature** | `docs/[feature].md` | How this feature works, usage, integration | Feature changes, bug fixes |
| **Code** | godoc, comments | Purpose, design decisions, data flows, constraints | Code changes |

### Cross-Reference Guidelines
- Feature docs link to relevant packages
- Code-level docs reference feature docs: `See docs/[feature].md for detailed architecture`
- Don't duplicate - code docs summarize, feature docs elaborate

### Choosing Documentation Layer

Use this decision tree to place documentation correctly:

```
START: What does this documentation explain?
│
├─► How the WHOLE SYSTEM works together?
│   └─► SYSTEM DOCS (docs/architecture.md)
│       Examples: component boundaries, cross-cutting concerns,
│       system-wide patterns, deployment architecture
│
├─► How to GET STARTED with the project?
│   └─► PROJECT DOCS (README.md, docs/getting-started.md)
│       Examples: setup, build, run, project structure overview
│
├─► How ONE FEATURE works end-to-end?
│   └─► FEATURE DOCS (docs/[feature].md)
│       Examples: problem/solution, feature architecture,
│       usage examples, integration points
│
└─► How ONE TYPE/FUNCTION works?
    └─► CODE DOCS (godoc, comments)
        Examples: type purpose, validation rules,
        function contracts, thread-safety
```

**Scope Test:**
| Scope | Layer | Example |
|-------|-------|---------|
| Affects ALL features | System | "All services use structured logging" |
| Affects ONE feature | Feature | "Auth service validates JWT tokens" |
| Affects ONE type | Code | "UserID must match pattern usr_*" |

### Handling Overlap

**Good Overlap (Summarize Up, Detail Down):**
```
System doc:  "Authentication uses JWT with 24h expiry"
                    ↓ references
Feature doc: "JWT Implementation: tokens signed with RS256,
             validated on each request, refreshed via /refresh endpoint"
                    ↓ references
Code doc:    "// TokenValidator checks signature and expiry.
             // See docs/auth.md for token lifecycle."
```

Each layer adds detail, none duplicates content verbatim.

**Bad Overlap (Copy-Paste Duplication):**
```
System doc:  "JWT tokens are signed with RS256 algorithm..."
Feature doc: "JWT tokens are signed with RS256 algorithm..." ← SAME TEXT
Code doc:    "// JWT tokens are signed with RS256 algorithm..." ← SAME TEXT
```

This WILL drift. When one is updated, others become stale.

**The Rule:**
- **Mention** at higher levels (1 sentence)
- **Explain** at the appropriate level (full detail)
- **Reference** between levels (links/pointers)

### Common Placement Mistakes

| Content | Wrong Layer | Right Layer | Why |
|---------|-------------|-------------|-----|
| "How auth works with database" | Code doc | Feature doc | Spans multiple types |
| "Error handling patterns" | Feature doc | System doc | Affects all features |
| "UserID validation regex" | Feature doc | Code doc | Single type detail |
| "Project directory structure" | Feature doc | Project doc | Onboarding info |
| "How to run tests" | System doc | Project doc | Getting started |

---

## Templates

### Feature Documentation Template

```markdown
# [Feature Name]

## Problem & Solution
**Problem**: [What user/system problem does this solve?]

**Solution**: [High-level approach taken]

## Key Players & Entry Points

### Entry Points (Start Here)
Where execution begins - the "front door" to this feature:
- `POST /api/users` → `UserHandler.Create()` - Creates new user
- `UserCreatedEvent` → `NotificationListener.OnUserCreated()` - Triggers welcome email
- `cli user create` → `CreateUserCommand.Run()` - CLI entry point

### Key Players
The main actors that make this feature work:

| Type | Role | File |
|------|------|------|
| `UserService` | Orchestrates user operations | `user/service.go` |
| `UserRepository` | Persists user data | `user/repository.go` |
| `UserID` | Self-validating identifier | `user/id.go` |
| `Email` | Self-validating email | `user/email.go` |

### Quick Navigation
- **To understand the flow**: Start at entry points, follow to UserService
- **To add validation**: Look at UserID, Email types
- **To change storage**: Implement UserRepository interface

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
[Step-by-step flow diagram or description]
Input → Validation → Processing → Storage → Output

### Integration Points
- **Consumed by**: [What uses this feature]
- **Depends on**: [What this feature uses]
- **Events/Hooks**: [If applicable]

## Usage

### Basic Usage
[Common case example with real, runnable code]

### Advanced Scenarios
[Complex case example showing edge cases]

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

### Package Godoc Template

```go
// Package [name] provides [high-level purpose].
//
// [1-2 sentences: what problem this solves]
//
// Main data flow:
//   Input → Validation → Processing → Output
//
// Core types:
//   - Type1: [Purpose and key responsibility]
//   - Type2: [Purpose and key responsibility]
//
// Design decisions:
//   - [Key decision and why - e.g., "Uses custom types to prevent primitive obsession"]
//
// Technical constraints:
//   - [Thread-safety notes, performance considerations, etc.]
//
// See docs/[feature].md for detailed architecture and usage examples.
package name
```

### Type Godoc Template

```go
// TypeName represents [domain concept].
//
// Purpose: [Why this type exists - what problem it solves]
//
// Design decision: [Why custom type vs primitive, validation approach, etc.]
//
// Data flow: [How data moves through this type, if non-obvious]
//   Constructor validates → methods operate on valid state → output is guaranteed valid
//
// Constraints:
//   - [Validation rules if self-validating]
//   - [Thread-safety guarantees]
//   - [Performance characteristics if relevant]
//
// Example:
//   id, err := NewUserID("usr_123")
//   if err != nil {
//       // handle validation error
//   }
//
// See docs/[feature].md for integration patterns.
type TypeName struct {
    // ...
}
```

### Function Godoc Template

Only document functions where behavior is non-obvious. Skip trivial getters/setters.

```go
// FunctionName [does what] for [purpose].
//
// Data flow: [Input] → [Processing steps] → [Output]
//
// Technical notes:
//   - [Non-obvious behavior]
//   - [Error conditions]
//   - [Performance characteristics]
//
// See docs/[feature].md#section for detailed flow diagrams.
func FunctionName(ctx context.Context, input InputType) (OutputType, error) {
    // ...
}
```

### Testable Example Template

```go
// Example_TypeName demonstrates typical usage of TypeName.
func Example_TypeName() {
    id, _ := NewUserID("usr_123")
    fmt.Println(id)
    // Output: usr_123
}

// Example_TypeName_validation shows validation behavior.
func Example_TypeName_validation() {
    _, err := NewUserID("")
    fmt.Println(err != nil)
    // Output: true
}
```

Testable examples show happy-path usage. Keep simple - complex scenarios belong in feature docs.

---

## Checklists

### Feature Documentation Checklist

**Problem & Solution Section**
- [ ] Clear problem statement (what user/system pain point?)
- [ ] High-level solution approach
- [ ] Why this solution was chosen over alternatives

**Key Players & Entry Points Section**
- [ ] Entry points listed (HTTP handlers, CLI commands, event listeners, etc.)
- [ ] Entry point → function mapping shown (e.g., `POST /users` → `UserHandler.Create()`)
- [ ] Key players table with Type, Role, and File location
- [ ] Quick navigation hints for common tasks

**Architecture Section**
- [ ] All core types listed with their purpose
- [ ] Design decisions explained with rationale
- [ ] Connections to coding principles (primitive obsession prevention, vertical slice, etc.)
- [ ] Data flow diagram or clear description
- [ ] Integration points with existing system documented

**Usage Section**
- [ ] Basic usage example with runnable code
- [ ] Advanced usage example showing edge cases
- [ ] Common patterns demonstrated
- [ ] Examples are copy-pasteable

**Testing Section**
- [ ] Unit test approach explained
- [ ] Integration test approach explained
- [ ] Coverage metrics and rationale provided

**Future Considerations**
- [ ] Known limitations documented
- [ ] Potential extensions noted
- [ ] Related features that could build on this mentioned

### Code Comments Checklist

**Package Documentation**
- [ ] Purpose: What problem this package solves
- [ ] Main data flow: Input → Processing → Output
- [ ] Core types: Listed with key responsibilities
- [ ] Design decisions: Key choices and rationale (brief)
- [ ] Technical constraints: Thread-safety, performance notes
- [ ] Reference: Links to feature docs for detailed architecture

**Type Documentation**
- [ ] Purpose: Why this type exists
- [ ] Design decision: Why custom type vs primitive
- [ ] Data flow: How data moves through this type (if non-obvious)
- [ ] Constraints: Validation rules, thread-safety, performance
- [ ] Example: Simple usage showing typical case
- [ ] Reference: Links to feature docs for integration patterns

**Function Documentation**
- [ ] Only for non-obvious behavior (skip trivial getters/setters)
- [ ] Data flow: Input → Processing → Output
- [ ] Technical notes: Error conditions, constraints
- [ ] Reference: Links to feature docs for detailed flows

**Testable Examples**
- [ ] At least one Example_* for complex/core types
- [ ] Examples are runnable (not pseudocode)
- [ ] Examples show happy-path usage only
- [ ] Output comments included for verification

---

## Guidelines

### Bug Fix Documentation

Bug fixes should NEVER add changelog-style entries. Instead, update existing docs to reflect correct behavior.

**Approach:**
1. Find the existing documentation for the affected behavior
2. Update it to describe the CORRECT behavior
3. If no docs exist, write behavior docs as if the bug never happened

**Example - Email Validation Bug:**
```
❌ DON'T ADD:
## Bug Fixes
- Fixed: Email validation now correctly rejects addresses without TLD

✅ DO UPDATE existing "Validation" section:
## Validation
Email addresses must include a valid TLD (e.g., .com, .org).
Invalid formats return ErrInvalidEmail with descriptive message.
```

**Example - Parser Edge Case:**
```
❌ DON'T ADD:
## v1.2.3 Changes
- Fixed edge case where empty input caused panic

✅ DO UPDATE existing "Input Handling" section:
## Input Handling
Empty input returns ErrEmptyInput. All inputs are validated before parsing.
```

**Why This Matters:**
Someone reading docs in 5 years wants to know: "How does validation work?"
They don't care that it was broken once - they need current behavior.

### Managing Documentation Size

**Split Signals:**
- Single doc exceeds ~500 lines
- Multiple distinct topics competing for attention
- Hard to find specific information
- Table of contents becomes unwieldy

**Folder Structure for Large Features:**
```
docs/
├── feature-name/
│   ├── README.md          # Index/overview (entry point)
│   ├── architecture.md    # Detailed architecture, diagrams
│   ├── usage.md           # Examples and patterns
│   └── api-reference.md   # Detailed API docs (if needed)
```

**Index File Requirements (README.md):**
- 1-2 paragraph overview of the feature
- Links to sub-documents with brief descriptions
- Quick navigation for common tasks
- This is the ONLY entry point - readers start here

**When NOT to Split:**
- Feature is cohesive and flows logically
- Splitting would create orphaned fragments
- Sub-docs would be too thin to stand alone

### Quality Gates

Before considering documentation complete, verify:

**Clarity Test**
- Can someone unfamiliar with the code read this and understand the feature?
- Are design decisions explained, not just described?
- Is technical jargon explained or avoided?

**AI Test**
- Can AI use this to fix a bug without reading all implementation code?
- Are integration points clearly documented?
- Are invariants and assumptions explicit?

**Maintenance Test**
- If the feature needs extension, is it clear where to add code?
- Are patterns documented so new code matches existing style?
- Are limitations and future considerations noted?

**Example Test**
- Can examples be copy-pasted and run with minimal setup?
- Do examples demonstrate real-world usage patterns?
- Are edge cases covered in advanced examples?

---

## Examples

### Anti-Patterns

#### ❌ Changelog-Style Entries
```markdown
## v1.2.3 Changes
- Fixed bug where validation allowed empty strings
- Updated error messages for clarity
- Refactored internal structure
```
*Why bad?*: Readers need current behavior, not history

#### ✅ Behavior-Focused Documentation
```markdown
## Validation
- Input must be non-empty string matching pattern `^[a-z]+$`
- Invalid input returns ErrInvalidInput with descriptive message
- Empty input is explicitly rejected (not silently ignored)
```

---

#### ❌ Implementation Details Without Context
```markdown
## Implementation
The CreateUser function calls validateEmail and then repo.Save.
It returns an error if validation fails.
```
*Why bad?*: Describes WHAT code does without WHY

#### ✅ Context-Rich Explanation
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

---

#### ❌ Feature List Without Purpose
```markdown
## Components
- UserID type
- Email type
- UserService
- Repository interface
- Notifier interface
```
*Why bad?*: No explanation of relationships or rationale

#### ✅ Purpose-Driven Structure
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

---

#### ❌ Code Dump as "Example"
```markdown
## Usage
See user_test.go for usage examples.
```
*Why bad?*: Forces reader to hunt through test code

#### ✅ Inline Runnable Examples
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

### Common Documentation Scenarios

#### Scenario 1: New Domain Type
Document:
- Why this type exists (what primitive obsession does it prevent?)
- What it validates
- How to construct it
- Where it's used in the system

#### Scenario 2: New Service/Orchestrator
Document:
- What business operations it provides
- What dependencies it requires (and why)
- How it fits into existing architecture
- Integration points with other services

#### Scenario 3: New Integration Point
Document:
- What external system/service is integrated
- Why this integration exists
- How data flows in/out
- Error handling strategy
- Retry/fallback behavior

#### Scenario 4: Refactored Architecture
Document:
- What problem the refactor solved
- What changed architecturally
- Why this approach was chosen
- Migration notes (if applicable)

### AI-Friendly Documentation Patterns

#### For Feature Extensions
AI needs to know:
- What patterns are established?
- Where are the natural extension points?
- What constraints must be maintained?

```markdown
## Extension Points
- **New validation rules**: Add to NewUserID constructor
- **New storage backends**: Implement Repository interface
- **New notification channels**: Add implementation of Notifier interface
- **New authentication methods**: Implement Authenticator interface
```

#### For Understanding Data Flow
AI needs to see:
- Entry points (how is this triggered?)
- Key transformation steps (what happens in sequence?)
- Exit points (what are the possible outcomes?)

```markdown
## Data Flow
1. HTTP handler receives POST /users → CreateUserRequest
2. Request validation → NewUserID, NewEmail (self-validating types)
3. UserService.CreateUser → validates business rules
4. Repository.Save → persists to database
5. Notifier.SendWelcome → sends welcome email (async)
6. Returns: User struct or validation/business error
```

#### Design Invariants
Document invariants that must be maintained:

```markdown
## Design Invariants
- UserID must always be non-empty after construction
- Email validation follows RFC 5322
- UserService assumes repository is never nil (validated in constructor)
- Password hashes use bcrypt with cost factor 12
```

### Testable Examples Best Practices

#### When to Add Example_* Functions
- Complex types with non-obvious usage
- Types with validation rules
- Common use case patterns
- Non-trivial workflows

#### Example_* Function Structure
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

#### Multiple Examples for Same Type
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
