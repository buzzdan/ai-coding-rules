# Code Design Principles

Core principles for designing Go types and architecture.

## 1. Primitive Obsession Prevention (Yoke Design Strategy)

### Principle
When it makes sense, avoid using primitives directly. Instead, create a type with proper named methods.

### When to Create a Type
A primitive should become a type when:
- It has validation rules
- It has behavior/logic associated with it
- It represents a domain concept
- It's used across multiple places
- Passing an invalid value would be a bug

### Pattern: Self-Validating Type
```go
// ❌ Primitive obsession
func CreateUser(id string, email string, port int) error {
    if id == "" {
        return errors.New("id required")
    }
    if !isValidEmail(email) {
        return errors.New("invalid email")
    }
    if port <= 0 || port >= 9000 {
        return errors.New("invalid port")
    }
    // ...
}

// ✅ Self-validating types
type UserID string
type Email string
type Port int

func NewUserID(s string) (UserID, error) {
    if s == "" {
        return "", errors.New("id required")
    }
    return UserID(s), nil
}

func NewEmail(s string) (Email, error) {
    if !isValidEmail(s) {
        return "", errors.New("invalid email")
    }
    return Email(s), nil
}

func NewPort(i int) (Port, error) {
    if i <= 0 || i >= 9000 {
        return 0, errors.New("port must be between 1 and 8999")
    }
    return Port(i), nil
}

func CreateUser(id UserID, email Email, port Port) error {
    // No validation needed - types guarantee validity
    // Pure business logic
}
```

### Benefits
- **Compile-time safety**: Can't pass wrong type
- **Centralized validation**: Rules in one place (constructor)
- **Self-documenting**: Type name explains purpose
- **Easier refactoring**: Change validation in one place

### Examples from Real Code
```go
// Parser complexity split into roles
type HeaderParser struct { /* ... */ }
type PathParser struct { /* ... */ }
type BodyParser struct { /* ... */ }

// Instead of one complex Parser with all logic
```

---

## 2. Self-Validating Types

### Principle
Types should validate their invariants in constructors. Methods should trust that the object is valid.

### Pattern: Private Fields + Validating Constructor
```go
// ❌ Non-self-validating
type UserService struct {
    Repo Repository  // Public, might be nil
}

func (s *UserService) CreateUser(user User) error {
    if s.Repo == nil {  // Defensive check in every method
        return errors.New("repo is nil")
    }
    return s.Repo.Save(user)
}

// ✅ Self-validating
type UserService struct {
    repo Repository  // Private
}

func NewUserService(repo Repository) (*UserService, error) {
    if repo == nil {
        return nil, errors.New("repo is required")
    }
    return &UserService{repo: repo}, nil
}

func (s *UserService) CreateUser(user User) error {
    // No nil check needed - constructor guarantees validity
    return s.repo.Save(user)
}
```

### Nil is Not a Valid Value
- Never return nil values (except errors: `nil, err` or `val, nil` is okay)
- Never pass nil into a function
- Check arguments in constructor, not in methods

### Avoid Defensive Coding
- Don't check for nil fields inside methods
- Constructor should guarantee object validity
- Methods can trust object state

---

## 3. Vertical Slice Architecture

### Principle
**Group by feature and behavior, not by technical layer.**

All code for a feature lives together in one directory.

### Examples

#### ❌ BAD: Horizontal Layers
```
internal/
├── handlers/health_handler.go
├── services/health_service.go
└── models/health.go
```
Problems: Feature scattered, hard to understand complete behavior, team conflicts

#### ✅ GOOD: Vertical Slice
```
internal/health/
├── handler.go
├── service.go
├── repository.go
└── models.go
```
Benefits: Feature colocated, easy to understand/extract, parallel work

### Migration Strategy

**New features**: Always implement as vertical slices
**Existing horizontal code**: Refactor incrementally

Create `docs/architecture/vertical-slice-migration.md`:
```markdown
# Vertical Slice Migration Plan
## Current State: [horizontal/mixed description]
## Target: Vertical slices in internal/[feature]/
## Strategy: New features vertical, refactor existing incrementally
## Progress: [x] new_feature (this PR), [ ] health, [ ] verification
```

**Never mix**: Don't have both `health/service.go` AND `services/health_service.go` for same feature.

---

## 4. Types Around Intent and Behavior

### Principle
Design types around intent and behavior, not just shape.

### Ask Before Creating a Type
- What is the purpose of this type?
- What invariants must it maintain?
- What behavior does it have?
- Why does it exist (beyond grouping fields)?

### Pattern: Types with Behavior
```go
// ❌ Type is just data container
type Config struct {
    Host string
    Port int
}

// ✅ Type has behavior and validation
type ServerAddress struct {
    host string
    port int
}

func NewServerAddress(host string, port int) (ServerAddress, error) {
    if host == "" {
        return ServerAddress{}, errors.New("host required")
    }
    if port <= 0 || port > 65535 {
        return ServerAddress{}, errors.New("invalid port")
    }
    return ServerAddress{host: host, port: port}, nil
}

func (a ServerAddress) String() string {
    return fmt.Sprintf("%s:%d", a.host, a.port)
}

func (a ServerAddress) IsLocal() bool {
    return a.host == "localhost" || a.host == "127.0.0.1"
}
```

---

## 5. Type File Organization

### Principle
Types with logic should be in their own file. Name the file after the type.

### Pattern
```
user/
├── user.go          # User type
├── user_id.go       # UserID type with validation
├── email.go         # Email type with validation
├── service.go       # UserService
└── repository.go    # Repository interface
```

### When to Extract to Own File
- Type has multiple methods
- Type has complex validation
- Type has significant documentation
- Type is important enough to be easily found

---

## 6. Leaf vs Orchestrating Types

### Leaf Types
**Definition**: Types not dependent on other custom types

**Characteristics:**
- Self-contained
- Minimal dependencies
- Pure logic
- Easy to test

**Example:**
```go
type UserID string
type Email string
type Age int

// These are leaf types - they depend only on primitives
```

**Testing:**
- Should have 100% unit test coverage
- Test only public API
- Use table-driven tests

### Orchestrating Types
**Definition**: Types that coordinate other types

**Characteristics:**
- Depend on other types (composition)
- Implement business workflows
- Minimal logic (mostly delegation)

**Example:**
```go
type UserService struct {
    repo     Repository
    notifier Notifier
}

// This orchestrates Repository and Notifier
```

**Testing:**
- Integration tests covering seams
- Test with real implementations, not mocks
- Can overlap with leaf type coverage

### Design Goal
**Most logic should be in leaf types.**
- Leaf types are easy to test and maintain
- Orchestrators should be thin wrappers

---

## 7. Abstraction Through Interfaces

### Principle
Don't create interfaces until you need them (avoid interface pollution).

### When to Create an Interface
- You have multiple implementations
- You need to inject dependency for testing
- You're defining a clear contract

### Pattern: Interface at Usage Point
```go
// In user/service.go
type Repository interface {  // Defined where used
    Save(ctx context.Context, u User) error
    Get(ctx context.Context, id UserID) (*User, error)
}

type UserService struct {
    repo Repository  // Depends on interface
}

// In user/postgres.go
type PostgresRepository struct {
    db *sql.DB
}

func (r *PostgresRepository) Save(ctx context.Context, u User) error {
    // Implementation
}

// In user/inmem.go
type InMemoryRepository struct {
    users map[UserID]User
}

func (r *InMemoryRepository) Save(ctx context.Context, u User) error {
    // Implementation
}
```

### Benefits
- Easy to test (use in-memory implementation)
- Can swap implementations
- Clear contract

### Don't Over-Abstract
```go
// ❌ Interface pollution
type UserGetter interface {
    Get(id UserID) (*User, error)
}

type UserSaver interface {
    Save(u User) error
}

type UserDeleter interface {
    Delete(id UserID) error
}

// ✅ Single cohesive interface
type Repository interface {
    Get(ctx context.Context, id UserID) (*User, error)
    Save(ctx context.Context, u User) error
    Delete(ctx context.Context, id UserID) error
}
```

---

## 8. Design Checklist (Pre-Code Review)

Before writing code, review:

### Can Logic Move to Smaller Types?
- [ ] Are there primitives that should be types?
- [ ] Can complex logic be split into multiple types?
- [ ] Example: Parser → HeaderParser + PathParser

### Type Intent
- [ ] Is type designed around behavior, not just shape?
- [ ] Does type have clear responsibility?
- [ ] Why does this type exist?

### Validation
- [ ] Is validation in constructor?
- [ ] Are fields private?
- [ ] Can methods trust object validity?

### Architecture
- [ ] Is this a vertical slice (not horizontal layer)?
- [ ] Are related types in same package?
- [ ] Is package name specific (not generic)?

### Dependencies
- [ ] Are dependencies injected through constructor?
- [ ] Are dependencies interfaces (if needed)?
- [ ] Is constructor validating dependencies?

Only after satisfactory answers → proceed to write code.

---

## 9. Common Go Anti-Patterns to Avoid

### Goroutine Leaks
Always ensure goroutines can exit:
```go
// ❌ Goroutine leak
func StartWorker() {
    go func() {
        for {
            // No way to exit
            work()
        }
    }()
}

// ✅ Goroutine with exit
func StartWorker(ctx context.Context) {
    go func() {
        for {
            select {
            case <-ctx.Done():
                return
            default:
                work()
            }
        }
    }()
}
```

### Interface Pollution
Don't create interfaces until you need them.

### Premature Optimization
Measure before optimizing.

### Ignoring Context
Always respect context cancellation:
```go
func DoWork(ctx context.Context) error {
    // Check context
    if err := ctx.Err(); err != nil {
        return err
    }
    // ...
}
```

### Mutex in Wrong Scope
Keep mutex close to data it protects:
```go
// ✅ Mutex with data
type SafeCounter struct {
    mu    sync.Mutex
    count int
}

func (c *SafeCounter) Inc() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}
```

---

## 10. Naming Conventions

### Package Names
- Use flatcase: `wekatrace`, not `wekaTrace` or `weka_trace`
- Avoid generic names: `util`, `common`, `helper`
- Avoid stdlib collisions: `metrics` collides with libs, use `wekametrics`

### Type Names
- Ergonomic: `version.Info` better than `version.VersionInfo`
- Context from package: `user.Service` better than `user.UserService`
- Avoid redundancy: method receiver provides context

### Method Names
```go
// ❌ Redundant
func (s *UserService) CreateUserAccount(u User) error

// ✅ Concise
func (s *UserService) Create(u User) error
```

### Idiomatic Go
- Write idiomatic Go code
- Follow Go community style and best practices
- Use effective Go guidelines

---

## Summary: Design Principles

1. **Prevent primitive obsession** - Create types for domain concepts
2. **Self-validating types** - Validate in constructor, trust in methods
3. **Vertical slices** - Group by feature, not layer
4. **Intent and behavior** - Design types around purpose
5. **File per type** - Types with logic get own file
6. **Leaf types** - Most logic in self-contained types
7. **Interfaces when needed** - Don't over-abstract
8. **Pre-code review** - Think before coding
9. **Avoid anti-patterns** - Goroutine leaks, premature optimization, etc.
10. **Idiomatic naming** - Follow Go conventions
