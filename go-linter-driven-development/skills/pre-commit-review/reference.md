# Design Principles Checklist

Complete validation guide with debt-based categorization.

## How to Use This Reference

This checklist is applied by the pre-commit-review skill using LLM reasoning to analyze code:

### Application Process
1. For each file under review, systematically apply all 8 categories below
2. For each detected issue, generate a finding with:
   - **Category**: Bug, Design Debt, Readability Debt, or Polish
   - **Location**: file:line with specific line numbers
   - **Issue**: Description with relevant code snippet
   - **Better**: Improved pattern with example code
   - **Why**: Impact explanation (maintenance, bugs, productivity)
   - **Fix**: Recommended approach (which skill, which pattern)
   - **Effort**: Time estimate for fixing

### Detection Strategy

**LLM analyzes code by asking questions for each principle:**
- Does this code violate a design principle? → Flag it
- How severe is the impact? → Categorize (Bug > Design > Readability > Polish)
- What's the better pattern? → Provide example
- How much effort to fix? → Estimate time

**Tools used during detection:**
- **Read tool**: Get file contents for analysis
- **Grep tool**: Find usage patterns, count occurrences, detect duplication across codebase
- **LLM reasoning**: Pattern match anti-patterns, apply heuristics, calculate scores

### Juiciness Scoring (for Primitive Obsession)

When detecting potential types, calculate juiciness score:

**Behavioral (rich behavior):**
- Complex validation (regex, ranges, business rules): +3
- Multiple meaningful methods (≥2): +2
- State transitions/transformations: +2
- Format conversions: +1

**Structural (organizing complexity):**
- Parsing unstructured data into fields: +3
- Grouping related data that travels together: +2
- Making implicit structure explicit: +2
- Replacing map[string]interface{}: +2

**Usage (simplifies code):**
- Used in 5+ places: +2
- Used in 3-4 places: +1
- Significantly simplifies calling code: +1
- Makes tests cleaner: +1

**Scoring:**
- Score ≥4: HIGH priority (clear win, recommend creating type)
- Score 2-3: MEDIUM priority (judgment call, present to user)
- Score 0-1: LOW priority (don't create type, over-engineering)

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

### Test Quality Review

Beyond structure, review if tests actually test the system properly.

#### Detection: Does Test Actually Test the SUT?

Look for:
- [ ] **Weak assertions**: Tests that pass but don't verify behavior
- [ ] **Missing use cases**: Important scenarios not covered
- [ ] **Mock overuse**: Mocking prevents testing real behavior
- [ ] **Test isolation**: Tests depend on each other or shared state
- [ ] **Incomplete verification**: Only checking happy path
- [ ] **Conditionals in tests**: wantErr bool pattern (violates complexity = 1)

#### ❌ Poor Test Quality

**Example 1: Weak Assertion**
```go
func TestCreateUser(t *testing.T) {
    svc := setupService()
    err := svc.CreateUser(ctx, user)

    assert.NoError(t, err)  // Only checks no error
    // ❌ Doesn't verify user was actually created!
    // ❌ Doesn't check user in database
    // ❌ Doesn't verify email was sent
}
```

**Example 2: Mock Prevents Real Testing**
```go
func TestDataProcessor(t *testing.T) {
    mockDB := &MockDatabase{}
    mockDB.On("Query", "SELECT...").Return(mockData, nil)

    processor := NewProcessor(mockDB)
    result := processor.Process()

    assert.Equal(t, expected, result)
    // ❌ Never tests real database interaction
    // ❌ Can't catch SQL syntax errors
    // ❌ Can't catch data marshaling issues
}
```

**Example 3: Missing Important Use Cases**
```go
func TestParseEmail(t *testing.T) {
    email, err := ParseEmail("test@example.com")
    assert.NoError(t, err)
    assert.Equal(t, "test@example.com", email.String())

    // ❌ Only tests happy path
    // ❌ Missing: empty string, invalid format, edge cases
}
```

**Example 4: Conditionals in Tests (wantErr anti-pattern)**
```go
func TestParseEmail(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    Email
        wantErr bool  // ❌ Anti-pattern
    }{
        {name: "valid", input: "test@example.com", want: Email("test@example.com")},
        {name: "empty", input: "", wantErr: true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseEmail(tt.input)

            if tt.wantErr {  // ❌ Conditional in test (complexity > 1)
                assert.Error(t, err)
                return
            }

            assert.NoError(t, err)
            assert.Equal(t, tt.want, got)
        })
    }
}
```

#### ✅ Good Test Quality

**Example 1: Complete Verification**
```go
func TestCreateUser(t *testing.T) {
    // Use real implementations
    db := setupTestDB(t)
    emailer := &TestEmailer{sent: []Email{}}

    svc := NewUserService(db, emailer)
    user := User{Email: "test@example.com", Name: "Test"}

    err := svc.CreateUser(ctx, user)
    require.NoError(t, err)

    // ✅ Verify user in database
    saved, err := db.GetUser(ctx, user.ID)
    require.NoError(t, err)
    assert.Equal(t, user.Email, saved.Email)
    assert.Equal(t, user.Name, saved.Name)

    // ✅ Verify email sent
    assert.Len(t, emailer.sent, 1)
    assert.Equal(t, user.Email, emailer.sent[0].To)
    assert.Contains(t, emailer.sent[0].Body, "Welcome")
}
```

**Example 2: Test Real Database**
```go
func TestUserRepository_Save(t *testing.T) {
    // ✅ Use real database (in-memory or testcontainers)
    db := setupPostgresTestContainer(t)
    // OR: db := setupInMemoryDB(t)

    repo := NewUserRepository(db)
    user := User{Email: "test@example.com"}

    // Test real database operations
    err := repo.Save(ctx, user)
    require.NoError(t, err)

    // Verify by querying database directly
    var count int
    err = db.QueryRow("SELECT COUNT(*) FROM users WHERE email = ?",
                      user.Email).Scan(&count)
    require.NoError(t, err)
    assert.Equal(t, 1, count)
}
```

**Example 3: Correct Pattern (Separate Functions, Complexity = 1)**

Instead of conditionals, use separate test functions:

```go
// ✅ Success cases - always expect success (no conditionals)
func TestParseEmail_Success(t *testing.T) {
    tests := []struct {
        name  string
        input string
        want  Email
    }{
        {name: "simple", input: "test@example.com", want: Email("test@example.com")},
        {name: "with plus", input: "test+tag@example.com", want: Email("test+tag@example.com")},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseEmail(tt.input)
            require.NoError(t, err)  // No conditionals
            assert.Equal(t, tt.want, got)
        })
    }
}

// ✅ Error cases - always expect error (no conditionals)
func TestParseEmail_Error(t *testing.T) {
    tests := []struct {
        name  string
        input string
    }{
        {name: "empty", input: ""},
        {name: "no @", input: "testexample.com"},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            _, err := ParseEmail(tt.input)
            assert.Error(t, err)  // No conditionals
        })
    }
}
```

**See [testing/reference.md](../testing/reference.md) for complete testing patterns and anti-patterns.**

#### Test Quality Checkpoints

When reviewing tests, check:

**1. Real Implementation Usage**
- Database: Use in-memory DB or testcontainers (not mocks)
- Files: Use `t.TempDir()` or `os.CreateTemp()` (not mocks)
- HTTP: Use `httptest.Server` (not mocks)
- External services: Use real test instances or testcontainers
- Only mock when absolutely necessary (external APIs you don't control)

**2. Complete Verification**
- Assert actual behavior, not just "no error"
- Verify side effects (database changes, files written, messages sent)
- Check state before and after operation

**3. Use Case Coverage**
- ✅ Happy path + ✅ Edge cases + ✅ Error cases

**4. Test Independence**
- Tests can run in any order
- Use `t.Cleanup()` for cleanup
- No shared mutable state

**5. No Conditionals (Complexity = 1)**
- ❌ No `wantErr bool` with if statements
- ✅ Separate success/error test functions

**6. Meaningful Assertions**
- Use specific assertions with messages
- Verify business logic, not implementation

**For complete testing patterns and examples, see [testing/reference.md](../testing/reference.md)**

---

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

**Structure:**
- Are tests in same package? → Use pkg_test
- Testing private methods? → Test public API instead
- Using mocks heavily? → Use real implementations
- Using time.Sleep? → Use channels/wait groups

**Quality:**
- Does test verify actual behavior? → Add meaningful assertions
- Are important use cases covered? → Add edge cases and error cases
- Using mocks where real implementation possible? → Use testcontainers/in-memory/temp files
- Do tests verify side effects? → Check database/files/messages
- Are tests independent? → Use t.Cleanup(), avoid shared state
- Conditionals in tests (wantErr)? → Separate success and error test functions

### Fix
Use @testing skill to restructure tests

---

## 8. Design Bugs [Bug 🐛]

### Detection
Look for:
- [ ] Potential nil dereferences
- [ ] Errors assigned to `_` (silently ignored)
- [ ] Missing defer for resource cleanup
- [ ] Race conditions (shared state without synchronization)
- [ ] Context not propagated (using context.Background() in call chain)
- [ ] Invalid nil returns (returning nil for non-error values)
- [ ] time.Sleep in production code (should use timers/contexts)
- [ ] Goroutine leaks (no way to exit)

### Examples

#### ❌ Bug: Potential Nil Dereference
```go
user := getUser()  // Can return user with nil Profile
email := user.Profile.Email  // Panic if Profile is nil
```

**Problems:**
- Crash risk if Profile is nil
- No defensive check
- Hard to debug in production

#### ✅ Fixed
```go
user := getUser()
if user.Profile == nil {
    return errors.New("user has no profile")
}
email := user.Profile.Email
```

**Better: Self-validating User type**
```go
func NewUser(..., profile Profile) (*User, error) {
    if profile == nil {
        return nil, errors.New("profile required")
    }
    return &User{Profile: profile}, nil
}

// Now Profile is guaranteed non-nil
func (u *User) GetEmail() string {
    return u.Profile.Email  // Safe, no check needed
}
```

#### ❌ Bug: Ignored Error
```go
_ = client.Record(metric)  // Silent failure
```

**Problems:**
- If metrics recording fails, no visibility
- Hard to debug production issues
- Violates fail-fast principle

#### ✅ Fixed
```go
if err := client.Record(metric); err != nil {
    log.Printf("failed to record metric: %v", err)
}

// Better: Return error if it's critical
if err := client.Record(metric); err != nil {
    return fmt.Errorf("record metric: %w", err)
}
```

#### ❌ Bug: Resource Leak
```go
func processFile(path string) error {
    f, err := os.Open(path)
    if err != nil {
        return err
    }

    data, err := io.ReadAll(f)
    if err != nil {
        return err  // File never closed!
    }

    f.Close()
    return process(data)
}
```

**Problems:**
- Early return doesn't close file
- Resource leak
- Can exhaust file descriptors

#### ✅ Fixed
```go
func processFile(path string) error {
    f, err := os.Open(path)
    if err != nil {
        return err
    }
    defer f.Close()  // Always closes, even on early return

    data, err := io.ReadAll(f)
    if err != nil {
        return err
    }

    return process(data)
}
```

#### ❌ Bug: Context Not Propagated
```go
func (s *Service) CreateUser(ctx context.Context, user User) error {
    // Ignoring ctx, using Background
    return s.repo.Save(context.Background(), user)
}
```

**Problems:**
- Cancellation not respected
- Timeouts don't work
- Can't trace requests

#### ✅ Fixed
```go
func (s *Service) CreateUser(ctx context.Context, user User) error {
    return s.repo.Save(ctx, user)  // Propagate context
}
```

#### ❌ Bug: Invalid Nil Return
```go
func FindUser(id string) *User {
    // ...
    return nil  // Nil is not a valid value for non-error returns
}
```

**Problems:**
- Caller must check for nil
- Easy to forget nil check
- Violates "nil is not a valid value" principle

#### ✅ Fixed
```go
func FindUser(id UserID) (*User, error) {
    user, found := users[id]
    if !found {
        return nil, fmt.Errorf("user not found: %s", id)
    }
    return &user, nil
}
```

#### ❌ Bug: Goroutine Leak
```go
func startWorker() {
    go func() {
        for {
            work := <- workChan
            process(work)
            // No way to exit this goroutine!
        }
    }()
}
```

**Problems:**
- Goroutine runs forever
- Memory leak
- Can't shutdown cleanly

#### ✅ Fixed
```go
func startWorker(ctx context.Context) {
    go func() {
        for {
            select {
            case work := <- workChan:
                process(work)
            case <-ctx.Done():
                return  // Clean exit
            }
        }
    }()
}
```

### Review Questions
- Can anything panic? → Check nil flows
- Are errors handled? → No `_ = ...`
- Are resources cleaned up? → Check defer usage
- Is context propagated? → No context.Background in chains
- Can goroutines exit? → Check cancellation

### Fix
**Fix bugs immediately before any refactoring work.**
- Nil issues → Add validation or use self-validating types
- Ignored errors → Log at minimum, return if critical
- Resource leaks → Add defer statements
- Context issues → Propagate ctx through call chain
- Goroutine leaks → Add cancellation via context

---

## Review Process Summary

For each modified file:

1. **Run Checklist** (#1-8 above)
2. **Categorize Findings**:
   - 🐛 Bugs: Nil deref, ignored errors, resource leaks (fix immediately)
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
