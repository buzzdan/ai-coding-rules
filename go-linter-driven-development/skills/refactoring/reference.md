# Refactoring Patterns Reference

Complete guide for linter-driven refactoring with decision tree and patterns.

## Refactoring Decision Tree

When linter fails or code feels complex, use this decision tree:

### Question 1: Does this code read like a story?
**Check**: Does it mix different levels of abstractions?

```go
// ❌ No - Mixes abstractions
func CreatePizza(order Order) Pizza {
    pizza := Pizza{Base: order.Size}  // High-level

    // Low-level temperature control
    for oven.Temp < cookingTemp {
        time.Sleep(checkOvenInterval)
        oven.Temp = getOvenTemp(oven)
    }

    return pizza
}

// ✅ Yes - Story-like
func CreatePizza(order Order) Pizza {
    pizza := prepare(order)
    bake(pizza)
    return pizza
}
```

**Action**: Break it down to same level of abstraction. Hide nitty-gritty details behind methods with proper names.

### Question 2: Can this be broken into smaller pieces?
**By what**: Responsibility? Task? Category?

Breaking down can be done at all levels:
- Extract a variable
- Extract a function
- Create a new type
- Create a new package

```go
// ❌ Multiple responsibilities
func HandleUserRequest(w http.ResponseWriter, r *http.Request) {
    // Parse request
    var user User
    json.NewDecoder(r.Body).Decode(&user)

    // Validate
    if user.Email == "" { /* ... */ }

    // Save to DB
    db.Exec("INSERT INTO...")

    // Send response
    json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

// ✅ Separated by responsibility
func HandleUserRequest(w http.ResponseWriter, r *http.Request) {
    user, err := parseUser(r)
    if err != nil {
        respondError(w, err)
        return
    }

    if err := validateUser(user); err != nil {
        respondError(w, err)
        return
    }

    if err := saveUser(user); err != nil {
        respondError(w, err)
        return
    }

    respondSuccess(w)
}
```

### Question 3: Does logic run on a primitive?
**Check**: Is this primitive obsession?

If logic operates on string/int/float, consider creating a type.

```go
// ❌ Primitive obsession
func ValidateEmail(email string) bool {
    return strings.Contains(email, "@")
}

func SendEmail(email string, subject, body string) error {
    if !ValidateEmail(email) {
        return errors.New("invalid email")
    }
    // Send
}

// ✅ Custom type
type Email string

func NewEmail(s string) (Email, error) {
    if !strings.Contains(s, "@") {
        return "", errors.New("invalid email")
    }
    return Email(s), nil
}

func SendEmail(email Email, subject, body string) error {
    // No validation needed - type guarantees validity
    // Send
}
```

**Note**: Cohesion is more important than coupling. Put logic where it belongs, even if it creates dependencies.

### Question 4: Is function long due to switch statement?
**Check**: Can cases be categorized and extracted?

```go
// ❌ Long switch statement
func ProcessEvent(eventType string, data interface{}) error {
    switch eventType {
    case "user_created":
        // 20 lines
    case "user_updated":
        // 25 lines
    case "user_deleted":
        // 15 lines
    // ... more cases
    }
}

// ✅ Extracted case handlers
func ProcessEvent(eventType string, data interface{}) error {
    switch eventType {
    case "user_created":
        return handleUserCreated(data)
    case "user_updated":
        return handleUserUpdated(data)
    case "user_deleted":
        return handleUserDeleted(data)
    default:
        return errors.New("unknown event type")
    }
}

func handleUserCreated(data interface{}) error { /* ... */ }
func handleUserUpdated(data interface{}) error { /* ... */ }
func handleUserDeleted(data interface{}) error { /* ... */ }
```

### Question 5: Types with logic?
**Rule**: Types with logic should be in their own file. Name file after type.

```
user/
├── user.go          # User type
├── user_id.go       # UserID type with logic
├── email.go         # Email type with logic
└── service.go       # UserService
```

---

## Detailed Refactoring Patterns

### 1. Storifying (Abstraction Levels)

**Signal:**
- Linter: High cognitive complexity
- Code smell: Mixed high-level and low-level code

**Pattern:**
```go
// Before
func ProcessOrder(order Order) error {
    // Validation
    if order.ID == "" { return errors.New("invalid") }
    if len(order.Items) == 0 { return errors.New("no items") }
    for _, item := range order.Items {
        if item.Price < 0 { return errors.New("negative price") }
    }

    // Database
    db, err := sql.Open("postgres", os.Getenv("DB_URL"))
    if err != nil { return err }
    defer db.Close()

    tx, err := db.Begin()
    if err != nil { return err }

    // SQL queries
    _, err = tx.Exec("INSERT INTO orders...")
    // ... many more lines

    // Email
    smtp, err := mail.Dial("smtp.example.com:587")
    // ... email sending logic

    return nil
}

// After
func ProcessOrder(order Order) error {
    if err := validateOrder(order); err != nil {
        return err
    }

    if err := saveToDatabase(order); err != nil {
        return err
    }

    if err := notifyCustomer(order); err != nil {
        return err
    }

    return nil
}
```

**Benefits:**
- Clear flow (validate → save → notify)
- Each function single responsibility
- Easy to test
- Easy to modify

**Real-world example:** See [Example 1 in examples.md](./examples.md#example-1-storifying-mixed-abstractions-and-extracting-logic-into-leaf-types) for a production case of storifying mixed abstractions and extracting a leaf type for IP collection logic

### 2. Extract Type (Primitive Obsession)

**Signal:**
- Linter: High cyclomatic complexity (due to validation)
- Code smell: Validation repeated across codebase

**Pattern:**
```go
// Before: Validation scattered
func CreateServer(host string, port int) (*Server, error) {
    if host == "" {
        return nil, errors.New("host required")
    }
    if port <= 0 || port > 65535 {
        return nil, errors.New("invalid port")
    }
    // ...
}

func ConnectToServer(host string, port int) error {
    if host == "" {
        return errors.New("host required")
    }
    if port <= 0 || port > 65535 {
        return errors.New("invalid port")
    }
    // ...
}

// After: Self-validating types
type Host string
type Port int

func NewHost(s string) (Host, error) {
    if s == "" {
        return "", errors.New("host required")
    }
    return Host(s), nil
}

func NewPort(p int) (Port, error) {
    if p <= 0 || p > 65535 {
        return 0, errors.New("port must be 1-65535")
    }
    return Port(p), nil
}

type ServerAddress struct {
    host Host
    port Port
}

func NewServerAddress(host Host, port Port) ServerAddress {
    // No validation needed - types are already valid
    return ServerAddress{host: host, port: port}
}

func (a ServerAddress) String() string {
    return fmt.Sprintf("%s:%d", a.host, a.port)
}

func CreateServer(addr ServerAddress) (*Server, error) {
    // No validation needed
    // ...
}

func ConnectToServer(addr ServerAddress) error {
    // No validation needed
    // ...
}
```

**Benefits:**
- Validation centralized
- Type safety
- Reduced complexity
- Self-documenting

**Real-world example:** See [Example 2 in examples.md](./examples.md#example-2-primitive-obsession-with-multiple-types-and-storifying-switch-statements) for extracting multiple types from a 60-line function with primitive obsession. Shows the Type Alias Pattern for creating config-friendly types and eliminating switch statement duplication.

---

### 2.5. The Over-Abstraction Trap ⚠️

**Critical**: Not every primitive needs a type. The goal is **clarity**, not **type proliferation**.

#### Quick Decision Checklist

**Create types when they**:
- ✅ Have multiple meaningful methods (>1) with real logic
- ✅ Enforce invariants/validation at construction
- ✅ Hide complex implementation
- ✅ Need controlled mutation → use **private fields**, NOT wrappers

**DON'T create types when they**:
- ❌ Just wrap primitives with one trivial method
- ❌ Add ceremony without benefit
- ❌ Good naming achieves same clarity

#### Bad vs Good: One Example

```go
// ❌ Bad: Trivial wrapper - 8 lines, no benefit
type CIDRPresence bool
func (p CIDRPresence) IsSet() bool { return bool(p) }

// ✅ Good: Private fields - same safety, less code
type CIDRConfig struct {
    clusterCIDRSet bool  // Only parser can set
    serviceCIDRSet bool
}
func (c CIDRConfig) ClusterCIDRSet() bool { return c.clusterCIDRSet }
```

#### Complete Teaching & Examples

**→ See [Example 2: Over-Abstraction Section](./examples.md#first-refactoring-attempt-the-over-abstraction-trap)**

Full case study includes:
- Complete thought process & comparisons
- 6 questions before creating a type
- Balance diagram & decision tree
- When to stop refactoring

---

### 3. Early Returns (Reduce Nesting)

**Signal:**
- Linter: High cyclomatic complexity
- Code smell: Nesting > 2 levels

**Pattern:**
```go
// Before: Deep nesting
func ProcessRequest(req Request) error {
    if req.IsValid() {
        if req.HasAuth() {
            if req.HasPermission() {
                // Do work
                result, err := doWork(req)
                if err != nil {
                    return err
                }
                return saveResult(result)
            } else {
                return errors.New("no permission")
            }
        } else {
            return errors.New("not authenticated")
        }
    } else {
        return errors.New("invalid request")
    }
}

// After: Early returns
func ProcessRequest(req Request) error {
    if !req.IsValid() {
        return errors.New("invalid request")
    }

    if !req.HasAuth() {
        return errors.New("not authenticated")
    }

    if !req.HasPermission() {
        return errors.New("no permission")
    }

    result, err := doWork(req)
    if err != nil {
        return err
    }

    return saveResult(result)
}
```

**Benefits:**
- Reduced nesting (max 1 level)
- Easier to read (guard clauses up front)
- Lower cyclomatic complexity

### 4. Extract Function (Long Functions)

**Signal:**
- Function > 50 LOC
- Multiple distinct concerns

**Pattern:**
```go
// Before: Long function (80 LOC)
func RegisterUser(data map[string]interface{}) error {
    // Parsing (15 lines)
    email, ok := data["email"].(string)
    if !ok { return errors.New("email required") }
    // ... more parsing

    // Validation (20 lines)
    if email == "" { return errors.New("email required") }
    if !strings.Contains(email, "@") { return errors.New("invalid email") }
    // ... more validation

    // Database (25 lines)
    db, err := getDB()
    if err != nil { return err }
    // ... DB operations

    // Email (15 lines)
    smtp := getSMTP()
    // ... email sending

    // Logging (5 lines)
    log.Printf("User registered: %s", email)
    // ...

    return nil
}

// After: Extracted functions
func RegisterUser(data map[string]interface{}) error {
    user, err := parseUserData(data)
    if err != nil {
        return err
    }

    if err := validateUser(user); err != nil {
        return err
    }

    if err := saveUserToDB(user); err != nil {
        return err
    }

    if err := sendWelcomeEmail(user); err != nil {
        return err
    }

    logUserRegistration(user)
    return nil
}

func parseUserData(data map[string]interface{}) (*User, error) {
    // 15 lines
}

func validateUser(user *User) error {
    // 20 lines
}

func saveUserToDB(user *User) error {
    // 25 lines
}

func sendWelcomeEmail(user *User) error {
    // 15 lines
}

func logUserRegistration(user *User) {
    // 5 lines
}
```

**Guidelines:**
- Aim for functions under 50 LOC
- Each function single responsibility
- Top-level function reads like a story

### 5. Switch Statement Extraction

**Signal:**
- Long function due to switch statement
- Each case is complex

**Pattern:**
```go
// Before
func RouteHandler(action string, params map[string]string) error {
    switch action {
    case "create":
        // Validate create params
        if params["name"] == "" { return errors.New("name required") }
        // ... 15 more lines
        return db.Create(...)

    case "update":
        // Validate update params
        if params["id"] == "" { return errors.New("id required") }
        // ... 20 more lines
        return db.Update(...)

    case "delete":
        // Validate delete params
        // ... 12 more lines
        return db.Delete(...)

    default:
        return errors.New("unknown action")
    }
}

// After
func RouteHandler(action string, params map[string]string) error {
    switch action {
    case "create":
        return handleCreate(params)
    case "update":
        return handleUpdate(params)
    case "delete":
        return handleDelete(params)
    default:
        return errors.New("unknown action")
    }
}

func handleCreate(params map[string]string) error {
    // All create logic (15 lines)
}

func handleUpdate(params map[string]string) error {
    // All update logic (20 lines)
}

func handleDelete(params map[string]string) error {
    // All delete logic (12 lines)
}
```

### 6. Defer Complexity Extraction

**Signal:**
- Linter: Defer function has cyclomatic complexity > 1

**Pattern:**
```go
// Before: Complex defer
func ProcessFile(filename string) error {
    f, err := os.Open(filename)
    if err != nil {
        return err
    }

    defer func() {
        if err := f.Close(); err != nil {
            if !errors.Is(err, fs.ErrClosed) {
                log.Printf("Error closing file: %v", err)
            }
        }
    }()

    // Process file
    return nil
}

// After: Extracted cleanup function
func ProcessFile(filename string) error {
    f, err := os.Open(filename)
    if err != nil {
        return err
    }
    defer closeFile(f)

    // Process file
    return nil
}

func closeFile(f *os.File) {
    if err := f.Close(); err != nil {
        if !errors.Is(err, fs.ErrClosed) {
            log.Printf("Error closing file: %v", err)
        }
    }
}
```

---

## Linter-Specific Refactoring

### Cyclomatic Complexity
**Cause**: Too many decision points (if, switch, for, &&, ||)

**Solutions:**
1. Extract functions for different branches
2. Use early returns to reduce nesting
3. Extract type with methods for primitive logic
4. Simplify boolean expressions

### Cognitive Complexity
**Cause**: Code hard to understand (nested logic, mixed abstractions)

**Solutions:**
1. Storifying (clarify abstraction levels)
2. Extract nested logic to named functions
3. Use early returns
4. Break into smaller, focused functions

### Maintainability Index
**Cause**: Code difficult to maintain

**Solutions:**
1. All of the above
2. Improve naming
3. Add comments for complex logic
4. Reduce coupling

---

## Guidelines for Effective Refactoring

### Keep Functions Small
- Target: Under 50 LOC
- Max 2 nesting levels
- Single responsibility

### Prefer Simplicity
- Simple, straightforward solutions over complex ones
- Descriptive variable and function names
- Avoid magic numbers and strings

### Maintain Tests
- Tests should pass after refactoring
- Add tests for new functions if needed
- Maintain or improve coverage

### Avoid Global State
- No global variables
- Inject dependencies through constructors
- Keep state localized

---

## Common Refactoring Scenarios

### Scenario 1: Linter Says "Cyclomatic Complexity Too High"
1. Identify decision points (if, switch, loops)
2. Extract branches to separate functions
3. Consider early returns
4. Check for primitive obsession (move logic to type)

### Scenario 2: Function Feels Hard to Test
1. Probably doing too much → Extract functions
2. Might have hidden dependencies → Inject through constructor
3. Might mix concerns → Separate responsibilities

### Scenario 3: Code Duplicated Across Functions
1. Extract common logic to shared function
2. Consider if primitives should be types (with methods)
3. Check if behavior belongs on existing type

### Scenario 4: Can't Name Function Clearly
1. Probably doing too much → Split responsibilities
2. Might be at wrong abstraction level
3. Reconsider what the function should do

---

## After Refactoring Checklist

- [ ] Linter passes (`task lintwithfix`)
- [ ] Tests pass (`go test ./...`)
- [ ] Coverage maintained or improved
- [ ] Code more readable
- [ ] Functions under 50 LOC
- [ ] Max 2 nesting levels
- [ ] Each function has clear purpose

---

## Integration with Design Principles

Refactoring often reveals design issues. After refactoring, consider:

**Created new types?**
→ Use @code-designing to validate type design

**Changed architecture?**
→ Ensure still following vertical slice structure

**Extracted significant logic?**
→ Ensure tests cover new functions (100% for leaf types)

---

## Summary: Refactoring Decision Tree

```
Linter fails or code complex
    ↓
1. Does it read like a story?
    No → Extract functions for abstraction levels
    ↓
2. Can it be broken into smaller pieces?
    Yes → By responsibility/task/category?
          Extract functions/types/packages
    ↓
3. Does logic run on primitives?
    Yes → Is this primitive obsession?
          Create custom type with methods
    ↓
4. Is it long due to switch statement?
    Yes → Extract case handlers
    ↓
5. Deeply nested if/else?
    Yes → Early returns or extract functions
    ↓
Re-run linter → Should pass
Run tests → Should pass
If new types → Validate with @code-designing
```

**Remember**: Cohesion > Coupling. Put logic where it belongs.
