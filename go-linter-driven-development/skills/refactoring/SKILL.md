# Refactoring

Linter-driven refactoring patterns to reduce complexity and improve code quality.

## When to Use
- Linter fails with complexity issues (cyclomatic, cognitive, maintainability)
- Code feels hard to read or maintain
- Functions are too long or deeply nested
- Automatically invoked by @linter-driven-development when linter fails

## Refactoring Signals

### Linter Failures
- **Cyclomatic Complexity**: Too many decision points → Extract functions, simplify logic
- **Cognitive Complexity**: Hard to understand → Storifying, reduce nesting
- **Maintainability Index**: Hard to maintain → Break into smaller pieces

### Code Smells
- Functions > 50 LOC
- Nesting > 2 levels
- Mixed abstraction levels
- Unclear flow/purpose
- Primitive obsession

## Workflow

### 1. Interpret Linter Output
Run `task lintwithfix` and analyze failures:
```
user/service.go:45:1: cyclomatic complexity 15 of func `CreateUser` is high (> 10)
user/handler.go:23:1: cognitive complexity 25 of func `HandleRequest` is high (> 15)
```

### 2. Diagnose Root Cause
For each failure, ask (see reference.md):
- Does this code read like a story? → Storifying needed
- Can this be broken into smaller pieces? → Extract functions/types
- Does logic run on primitives? → Primitive obsession
- Is function long due to switch statement? → Categorize and extract

### 3. Apply Refactoring Pattern
Choose appropriate pattern:
- **Storifying**: Extract helpers to clarify levels
- **Extract Type**: Move primitive logic to custom type
- **Extract Function**: Pull out complexity
- **Early Returns**: Reduce nesting
- **Switch Extraction**: Categorize cases

### 4. Verify Improvement
- Re-run linter
- Tests still pass
- Code more readable?

## Refactoring Patterns

### Pattern 1: Storifying (Mixed Abstractions)
**Signal**: Function mixes high-level steps with low-level details

```go
// ❌ Before - Mixed abstractions
func ProcessOrder(order Order) error {
    // Validation
    if order.ID == "" {
        return errors.New("invalid")
    }

    // Low-level DB setup
    db, err := sql.Open("postgres", connStr)
    if err != nil { return err }
    defer db.Close()

    // SQL construction
    query := "INSERT INTO..."
    // ... many lines

    return nil
}

// ✅ After - Story-like
func ProcessOrder(order Order) error {
    if err := validateOrder(order); err != nil {
        return err
    }

    if err := saveToDatabase(order); err != nil {
        return err
    }

    return notifyCustomer(order)
}

func validateOrder(order Order) error { /* ... */ }
func saveToDatabase(order Order) error { /* ... */ }
func notifyCustomer(order Order) error { /* ... */ }
```

### Pattern 2: Extract Type (Primitive Obsession)
**Signal**: Complex logic operating on primitives

```go
// ❌ Before - Primitive obsession
func ValidatePort(port int) error {
    if port <= 0 || port >= 9000 {
        return errors.New("invalid port")
    }
    return nil
}

func GetServiceURL(host string, port int) string {
    return fmt.Sprintf("%s:%d", host, port)
}

// ✅ After - Custom type
type Port int

func NewPort(p int) (Port, error) {
    if p <= 0 || p >= 9000 {
        return 0, errors.New("invalid port")
    }
    return Port(p), nil
}

func (p Port) Int() int {
    return int(p)
}

type ServiceAddress struct {
    host string
    port Port
}

func (a ServiceAddress) URL() string {
    return fmt.Sprintf("%s:%d", a.host, a.port)
}
```

### Pattern 3: Extract Function (Long Functions)
**Signal**: Function > 50 LOC or multiple responsibilities

```go
// ❌ Before - Long function
func CreateUser(data map[string]interface{}) error {
    // Validation (15 lines)
    // ...

    // Database operations (20 lines)
    // ...

    // Email notification (10 lines)
    // ...

    // Logging (5 lines)
    // ...

    return nil
}

// ✅ After - Extracted functions
func CreateUser(data map[string]interface{}) error {
    user, err := validateAndParseUser(data)
    if err != nil {
        return err
    }

    if err := saveUser(user); err != nil {
        return err
    }

    if err := sendWelcomeEmail(user); err != nil {
        return err
    }

    logUserCreation(user)
    return nil
}
```

### Pattern 4: Early Returns (Deep Nesting)
**Signal**: Nesting > 2 levels

```go
// ❌ Before - Deeply nested
func ProcessItem(item Item) error {
    if item.IsValid() {
        if item.IsReady() {
            if item.HasPermission() {
                // Process
                return nil
            } else {
                return errors.New("no permission")
            }
        } else {
            return errors.New("not ready")
        }
    } else {
        return errors.New("invalid")
    }
}

// ✅ After - Early returns
func ProcessItem(item Item) error {
    if !item.IsValid() {
        return errors.New("invalid")
    }

    if !item.IsReady() {
        return errors.New("not ready")
    }

    if !item.HasPermission() {
        return errors.New("no permission")
    }

    // Process
    return nil
}
```

### Pattern 5: Switch Extraction (Long Switch)
**Signal**: Switch statement with complex cases

```go
// ❌ Before - Long switch in one function
func HandleRequest(reqType string, data interface{}) error {
    switch reqType {
    case "create":
        // 20 lines of creation logic
    case "update":
        // 20 lines of update logic
    case "delete":
        // 15 lines of delete logic
    default:
        return errors.New("unknown type")
    }
    return nil
}

// ✅ After - Extracted handlers
func HandleRequest(reqType string, data interface{}) error {
    switch reqType {
    case "create":
        return handleCreate(data)
    case "update":
        return handleUpdate(data)
    case "delete":
        return handleDelete(data)
    default:
        return errors.New("unknown type")
    }
}

func handleCreate(data interface{}) error { /* ... */ }
func handleUpdate(data interface{}) error { /* ... */ }
func handleDelete(data interface{}) error { /* ... */ }
```

## Refactoring Decision Tree

When linter fails, ask these questions (see reference.md for details):

1. **Does this read like a story?**
   - No → Extract functions for different abstraction levels

2. **Can this be broken into smaller pieces?**
   - By responsibility? → Extract functions
   - By task? → Extract functions
   - By category? → Extract functions

3. **Does logic run on primitives?**
   - Yes → Is this primitive obsession? → Extract type

4. **Is function long due to switch statement?**
   - Yes → Extract case handlers

5. **Are there deeply nested if/else?**
   - Yes → Use early returns or extract functions

## After Refactoring

### Verify
- [ ] Re-run `task lintwithfix` - Should pass
- [ ] Run tests - Should still pass
- [ ] Check coverage - Should maintain or improve
- [ ] Code more readable? - Get feedback if unsure

### May Need
- **New types created** → Use @code-designing to validate design
- **New functions added** → Ensure tests cover them
- **Major restructuring** → Consider using @pre-commit-review

## Output Format

```
🔧 REFACTORING COMPLETE

Linter Issues Resolved:
✅ user/service.go:45 - Cyclomatic complexity (15 → 8)
✅ user/handler.go:23 - Cognitive complexity (25 → 12)

Refactoring Applied:
1. Storifying: Extracted validateUser, saveUser, notifyUser
2. Extract Type: Created Port and ServiceAddress types
3. Early Returns: Reduced nesting in ProcessItem

Files Modified:
- user/service.go (+30, -45 lines)
- user/port.go (new file, +25 lines)
- user/address.go (new file, +35 lines)

Next Steps:
1. Re-run linter: task lintwithfix → Should pass
2. Run tests: go test ./... → Should pass
3. If new types created → Consider @code-designing review
4. Proceed to @pre-commit-review phase
```

## Integration with Other Skills

- **@code-designing**: When refactoring creates new types, validate design
- **@testing**: Ensure refactored code maintains test coverage
- **@pre-commit-review**: Final validation before commit

See reference.md for complete refactoring patterns and decision tree.
