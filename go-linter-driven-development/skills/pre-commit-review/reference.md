# Design Principles Checklist

Complete validation guide with debt-based categorization.

## 1. Primitive Obsession [Design Debt 🔴]

### Detection
Look for:
- [ ] String types representing domain concepts (userID, email, path)
- [ ] Int types representing domain values (Port, Age, StatusCode)
- [ ] Float types representing domain measurements (Price, Distance)
- [ ] Primitive parameters without validation
- [ ] Logic operating directly on primitives

### Examples

#### ❌ Design Debt
```go
func CompleteTask(id string) error {
    if id == "" {
        return ErrInvalidTaskID
    }
    // continue with logic...
    return nil
}

func CreateUser(id string, email string, age int) error {
    if id == "" {
        return errors.New("id required")
    }
    if !strings.Contains(email, "@") {
        return errors.New("invalid email")
    }
    if age < 0 || age > 150 {
        return errors.New("invalid age")
    }
    // ... business logic
}
```

Problems:
- Validation scattered across codebase
- No compile-time guarantees
- Easy to pass invalid values
- Harder to change validation rules

#### ✅ No Debt
```go
type TaskID string

func NewTaskID(s string) (TaskID, error) {
    if s == "" {
        return "", ErrInvalidTaskID
    }
    return TaskID(s), nil
}

func (s *TaskService) CompleteTask(id TaskID) error {
    // logic using validated TaskID - no validation needed
    return nil
}

// More comprehensive example
type UserID string
type Email string
type Age int

func NewUserID(s string) (UserID, error) {
    if s == "" {
        return "", errors.New("id required")
    }
    return UserID(s), nil
}

func NewEmail(s string) (Email, error) {
    if !strings.Contains(s, "@") {
        return "", errors.New("invalid email")
    }
    return Email(s), nil
}

func NewAge(i int) (Age, error) {
    if i < 0 || i > 150 {
        return 0, errors.New("invalid age")
    }
    return Age(i), nil
}

func CreateUser(id UserID, email Email, age Age) error {
    // No validation needed - types guarantee validity
    // ... business logic only
}
```

Benefits:
- Type safety at compile time
- Validation centralized in constructors
- Self-documenting code
- Easier to refactor

### Also Check: Enums
```go
// ❌ Design Debt
if status == "READY"

// ✅ No Debt
type Status string
const StatusReady Status = "READY"
```

### Review Questions
- Can this primitive be passed invalid? → Needs type
- Is validation repeated elsewhere? → Needs type
- Does this represent a domain concept? → Needs type

### Fix
Use @code-designing skill to create self-validating types

---

## 2. Storifying [Readability Debt 🟡]

### Detection
Look for:
- [ ] Functions mixing high-level steps with low-level details
- [ ] Implementation details obscuring business logic
- [ ] Long functions (>50 LOC) with multiple concerns
- [ ] Unclear flow/sequence of operations

### Examples

#### ❌ Readability Debt
```go
func createPizza(order *Order) *Pizza {
  pizza := &Pizza{Base: order.Size,
                  Sauce: order.Sauce,
                  Cheese: "Mozzarella"}

  // High-level: toppings
  if order.kind == "Veg" {
    pizza.Toppings = vegToppings
  } else if order.kind == "Meat" {
    pizza.Toppings = meatToppings
  }

  // Low-level: oven temperature control
  oven := oven.New()
  if oven.Temp != cookingTemp {
    for (oven.Temp < cookingTemp) {
      time.Sleep(checkOvenInterval)
      oven.Temp = getOvenTemp(oven)
    }
  }

  // Low-level: baking mechanics
  if !pizza.Baked {
    oven.Insert(pizza)
    time.Sleep(cookTime)
    oven.Remove(pizza)
    pizza.Baked = true
  }

  // High-level: boxing
  box := box.New()
  pizza.Boxed = box.PutIn(pizza)
  pizza.Sliced = box.SlicePizza(order.Size)
  pizza.Ready = box.Close()
  return pizza
}
```

Problems:
- Hard to understand flow at a glance
- Mixes abstraction levels (business + infrastructure)
- Difficult to test pieces independently
- Hard to modify one concern without affecting others

#### ✅ No Debt
```go
func createPizza(order *Order) *Pizza {
  pizza := prepare(order)
  bake(pizza)
  box(pizza)
  return pizza
}

func prepare(order *Order) *Pizza {
  pizza := &Pizza{Base: order.Size,
                  Sauce: order.Sauce,
                  Cheese: "Mozzarella"}
  addToppings(pizza, order.kind)
  return pizza
}

func addToppings(pizza *Pizza, kind string) {
  if kind == "Veg" {
    pizza.Toppings = vegToppings
  } else if kind == "Meat" {
    pizza.Toppings = meatToppings
  }
}

func bake(pizza *Pizza) {
  oven := oven.New()
  heatOven(oven)
  bakePizza(pizza, oven)
}

func heatOven(oven *Oven) { /* ... */ }
func bakePizza(pizza *Pizza, oven *Oven) { /* ... */ }
func box(pizza *Pizza) { /* ... */ }
```

Benefits:
- Reads like a story (prepare → bake → box)
- Each function single abstraction level
- Easy to test each step independently
- Clear where to make changes

### Principle
**Top-level functions should read like a story, not implementation**
- All steps clear and easy to understand at a glance
- Hide nitty-gritty details behind methods with proper names

### Review Questions
- Does this function read like steps or implementation? → Story = good
- Are there multiple abstraction levels? → Extract helpers
- Could I explain this flow in 3-5 steps? → Should match code structure

### Fix
Use @refactoring skill to extract functions and clarify abstraction levels

---

## 3. Self-Validating Types [Design Debt 🔴]

### Detection
Look for:
- [ ] Structs with public fields that need validation
- [ ] Methods checking if fields are nil/empty/invalid
- [ ] Validation happening outside constructors
- [ ] Defensive programming inside methods

### Examples

#### ❌ Design Debt
```go
type UserService struct {
    Repo       Repository  // Public, might be nil
    EmailSender EmailSender // Public, might be nil
}

func (s *UserService) CreateUser(ctx context.Context, user User) error {
    // Defensive checks in every method
    if s.Repo == nil {
        return errors.New("repo is nil")
    }
    if s.EmailSender == nil {
        return errors.New("email sender is nil")
    }

    // Actual logic
    return s.Repo.Save(ctx, user)
}

func (s *UserService) GetUser(ctx context.Context, id string) (*User, error) {
    // Must repeat checks in every method
    if s.Repo == nil {
        return nil, errors.New("repo is nil")
    }
    return s.Repo.Get(ctx, id)
}
```

Problems:
- Every method must check for nil
- Easy to forget defensive checks
- Can't trust object state
- Wastes time/code on validation

#### ✅ No Debt
```go
type UserService struct {
    repo        Repository  // Private
    emailSender EmailSender // Private
}

func NewUserService(repo Repository, emailSender EmailSender) (*UserService, error) {
    // Validate once in constructor
    if repo == nil {
        return nil, errors.New("repo is required")
    }
    if emailSender == nil {
        return nil, errors.New("email sender is required")
    }
    return &UserService{
        repo:        repo,
        emailSender: emailSender,
    }, nil
}

func (s *UserService) CreateUser(ctx context.Context, user User) error {
    // No validation needed - constructor guarantees validity
    return s.repo.Save(ctx, user)
}

func (s *UserService) GetUser(ctx context.Context, id UserID) (*User, error) {
    // No nil checks needed
    return s.repo.Get(ctx, id)
}
```

Benefits:
- Constructor validates once
- Methods trust object state
- Impossible to create invalid objects
- Less defensive code

### Principle
**Types should be self-validating:**
- Check arguments in constructor
- No need to check for nil object fields inside methods
- Avoid defensive coding

### Review Questions
- Do methods check field validity? → Move to constructor
- Are fields public when they shouldn't be? → Make private
- Can this object be invalid after construction? → Add validation

### Fix
Use @code-designing skill to add validating constructors

---

## 4. Abstraction Levels [Readability Debt 🟡]

### Detection
Look for:
- [ ] Business logic mixed with infrastructure code
- [ ] High-level concepts mixed with low-level operations
- [ ] Function doing "what" AND "how" simultaneously
- [ ] Different conceptual levels in same function

### Examples

#### ❌ Readability Debt
```go
func ProcessOrder(order Order) error {
    // High-level: validation
    if order.ID == "" {
        return errors.New("invalid order")
    }
    for _, item := range order.Items {
        if item.Price < 0 {
            return errors.New("invalid price")
        }
    }

    // Low-level: database connection
    db, err := sql.Open("postgres", os.Getenv("DB_URL"))
    if err != nil {
        return fmt.Errorf("db connection: %w", err)
    }
    defer db.Close()

    // Mixed: transaction handling
    tx, err := db.Begin()
    if err != nil {
        return err
    }

    // Low-level: SQL query construction
    query := "INSERT INTO orders (id, total) VALUES ($1, $2)"
    // ... many more lines of SQL/DB logic

    // High-level: notification
    if err := sendEmail(order.CustomerEmail, "Order confirmed"); err != nil {
        return err
    }

    return nil
}
```

Problems:
- Hard to understand flow at a glance
- Mixes business logic with infrastructure
- Difficult to test independently
- Hard to change one concern without affecting others

#### ✅ No Debt
```go
func ProcessOrder(order Order) error {
    if err := validateOrder(order); err != nil {
        return err
    }

    if err := saveOrder(order); err != nil {
        return err
    }

    if err := notifyCustomer(order); err != nil {
        return err
    }

    return nil
}

func validateOrder(order Order) error {
    // Validation logic only
}

func saveOrder(order Order) error {
    // Database logic only
}

func notifyCustomer(order Order) error {
    // Notification logic only
}
```

Benefits:
- Reads like a story (validate → save → notify)
- Each function single abstraction level
- Easy to test each step
- Clear separation of concerns

### Principle
**A function should operate at a single conceptual level**
- Don't mix low-level implementation with high-level business logic
- Don't mix business logic with infrastructure

### Review Questions
- Does this mix business and infrastructure? → Separate
- Are there different conceptual levels? → Extract layers
- Is the "what" clear or buried in "how"? → Clarify

### Fix
Use @refactoring skill to separate abstraction layers

---

## 5. Vertical Slice Architecture [Design Debt 🔴 - ADVISORY]

### Detection
Look for:
- [ ] Features split across domain/, services/, handlers/ directories
- [ ] Horizontal layering vs vertical slicing

**Note**: This is Design Debt but ADVISORY only. Never blocks. User may have valid reasons (time, team decisions).

### Examples

#### ⚠️ Horizontal Layering
```
internal/{handlers,services,domain}/feature.go
```
Problems: Feature scattered, coupling, team conflicts

#### ✅ Vertical Slicing
```
internal/feature/{handler,service,repository,models}.go
```
Benefits: Colocated, easy to understand, parallel work

### Advisory Messages

**Horizontal pattern**:
```
🔴 Design Debt (Advisory): Horizontal Layering
Vertical slicing preferred for: cohesion, maintainability, boundaries
Consider: Start migration with docs/architecture/vertical-slice-migration.md
Valid reasons to proceed: time constraints, team agreement
Proceed or refactor?
```

**Mixed without docs**:
```
💡 Polish: Document migration in docs/architecture/vertical-slice-migration.md
Helps team understand pattern and track progress.
```

**Vertical slice**:
```
✅ Architecture: Vertical Slice Pattern
Follows recommended pattern, feature colocated
```

### Fix
If user wants refactor: Use @code-designing skill

---

## 6. Naming [Readability Debt 🟡 or Polish 🟢]

### Detection
Look for:
- [ ] Generic names: utils, common, helpers, manager, handler (without context)
- [ ] Redundant names: UserService.CreateUserAccount
- [ ] Non-idiomatic names: getUserData vs GetUser
- [ ] Colliding names with stdlib or common libraries

### Examples

#### 🟡 Readability Debt (Generic/Vague)
```go
package common  // Too generic

type DataManager struct {  // Vague
    // ...
}

func ProcessData(data interface{}) interface{} {  // No meaning
    // ...
}
```

#### ✅ Better
```go
package user

type Service struct {  // Context from package
    // ...
}

func (s *Service) Create(u User) error {  // Clear action
    // ...
}
```

#### 🟢 Polish Opportunity (Less Idiomatic)
```go
// Less idiomatic
func (s *Service) CreateUserInDatabase(user User) error

// More idiomatic
func (s *Service) Create(user User) error  // Receiver provides context
```

### Principles
- **Write idiomatic Go code**
- **Use flatcase for package names** (e.g., `wekatrace`)
- **Ergonomic naming**: `version.Info` better than `version.VersionInfo`
- **Avoid generic names**: data, utils, common, domain
- **Avoid stdlib collisions**: Don't use `metrics` (collides with libs), use `wekametrics`

### Review Questions
🟡 Readability:
- Is the name generic/vague? → Make specific
- Does it collide with stdlib? → Choose unique name

🟢 Polish:
- Is it idiomatic? → Minor naming improvements
- Is it ergonomic? → Reduce redundancy

### Fix
🟡 Readability: Use @refactoring skill
🟢 Polish: Minor renaming

---

## 7. Testing Approach [Design Debt 🔴]

### Detection
Look for:
- [ ] Tests in same package (not pkg_test)
- [ ] Testing private methods/functions
- [ ] Heavy use of mocks instead of real implementations
- [ ] Tests with cyclomatic complexity > 1 (conditionals in tests)
- [ ] time.Sleep in tests

### Examples

#### ❌ Design Debt
```go
package user  // Same package - can test private

func TestInternalValidation(t *testing.T) {  // Testing private
    result := validateEmailInternal("test@example.com")
    assert.True(t, result)
}

func TestServiceWithMocks(t *testing.T) {
    mockRepo := &MockRepository{}  // Heavy mocking
    mockEmailer := &MockEmailer{}

    mockRepo.On("Save", mock.Anything).Return(nil)
    mockEmailer.On("Send", mock.Anything).Return(nil)

    svc := &UserService{Repo: mockRepo, EmailSender: mockEmailer}
    // Test with mocks
}

func TestWithSleep(t *testing.T) {
    go doWork()
    time.Sleep(100 * time.Millisecond)  // ❌ Flaky
    // assert
}
```

#### ✅ No Debt
```go
package user_test  // External package - tests public API only

func TestService_CreateUser(t *testing.T) {  // Test public API
    // Use real implementations
    repo := user.NewInMemoryRepository()
    emailer := user.NewTestEmailer()

    svc, err := user.NewUserService(repo, emailer)
    require.NoError(t, err)

    // Test public behavior
    err = svc.CreateUser(context.Background(), testUser)
    assert.NoError(t, err)
}

func TestWithChannel(t *testing.T) {
    done := make(chan struct{})
    go func() {
        doWork()
        close(done)
    }()

    select {
    case <-done:
        // Success
    case <-time.After(1 * time.Second):
        t.Fatal("timeout")
    }
}
```

### Principles

**Test Only Public API:**
- Use `pkg_test` package name
- Test types via constructors only
- No testing private methods

**Avoid Mocks:**
- Use real implementations (HTTP test servers, temp files, in-memory DBs)
- Test with actual dependencies (integration-style)

**Table-Driven Tests:**
- Good when each case has cyclomatic complexity = 1
- NO conditionals inside t.Run()
- Separate success/error cases into different test functions

**Testify Suites:**
- ONLY for complex infrastructure setup
- NOT for simple unit tests

**Synchronization:**
- Avoid time.Sleep
- Use wait groups or channels

**Coverage:**
- Leaf types: 100% unit test coverage
- Orchestrating types: Integration tests

### Review Questions
- Are tests in same package? → Use pkg_test
- Testing private methods? → Test public API instead
- Using mocks heavily? → Use real implementations
- Using time.Sleep? → Use channels/wait groups

### Fix
Use @testing skill to restructure tests

---

## Review Process Summary

For each modified file:

1. **Run Checklist** (#1-7 above)
2. **Categorize Findings**:
   - 🔴 Design Debt: Types, architecture, validation
   - 🟡 Readability Debt: Abstraction, flow, naming
   - 🟢 Polish: Minor improvements

3. **Check Broader Context**:
   - Similar issues in rest of file?
   - Pattern worth addressing holistically?

4. **Generate Report**:
   - Specific findings with locations
   - Concrete suggestions with examples
   - Impact explanations (why it matters)
   - Recommended skills to fix

5. **User Decision**:
   - Commit as-is
   - Fix specific debt categories
   - Expand scope to broader refactor

## Additional Principles from coding_rules.md

### Function Complexity
- Keep functions under 50 LOC
- Max 2 nesting levels
- Deeply nested if/else → Extract functions or early returns

### Nil Handling
- Never return nil values (except for errors: `nil, err` or `val, nil` is ok)
- Never pass nil into functions
- Avoid defensive nil checks in methods (validate in constructor)

### Defer Complexity
- If defer functions have cyclomatic complexity > 1 → Extract to separate function

### Test Coverage Strategy
- Leaf types (not dependent on others): 100% unit test coverage
- Most logic should be in leaf types
- Orchestrating types: Integration tests covering seams

### Linting
- Never use `nolint` directives without approval
- Try to fix code first
- If false positive, add to exclusions in `.golangci.yaml`
- Fix can be as simple as logging error instead of ignoring

### Table-Driven Tests
**ALWAYS use named struct fields:**
```go
// ❌ BAD - breaks when linter reorders fields
{name: "test1", 42, "result"},

// ✅ GOOD - works regardless of field order
{name: "test1", input: 42, want: "result"},
```
