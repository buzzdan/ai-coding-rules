# Pre-Commit Review Examples

Real-world examples of design review findings with before/after comparisons.

## Example 1: Primitive Obsession + Self-Validating Types

### Before (Design Debt 🔴)
```go
package user

type UserService struct {
    DB *sql.DB  // Might be nil
}

func (s *UserService) CreateUser(id string, email string) error {
    // Defensive check
    if s.DB == nil {
        return errors.New("db is nil")
    }

    // Primitive validation
    if id == "" {
        return errors.New("id required")
    }
    if !strings.Contains(email, "@") {
        return errors.New("invalid email")
    }

    // Business logic
    _, err := s.DB.Exec("INSERT INTO users (id, email) VALUES ($1, $2)", id, email)
    return err
}
```

**Review Findings:**
- 🔴 **Design Debt**: Primitive obsession on `id` and `email`
- 🔴 **Design Debt**: Non-self-validating type (`UserService.DB` might be nil)

### After (No Debt)
```go
package user

type UserID string
type Email string

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

type UserService struct {
    db *sql.DB
}

func NewUserService(db *sql.DB) (*UserService, error) {
    if db == nil {
        return nil, errors.New("db is required")
    }
    return &UserService{db: db}, nil
}

func (s *UserService) CreateUser(id UserID, email Email) error {
    // No validation needed - types guarantee validity
    _, err := s.db.Exec("INSERT INTO users (id, email) VALUES ($1, $2)", id, email)
    return err
}
```

---

## Example 2: Mixed Abstraction Levels + Storifying

### Before (Readability Debt 🟡)
```go
func ProcessPayment(orderID string, amount float64) error {
    // High-level: validation
    if orderID == "" {
        return errors.New("invalid order id")
    }
    if amount <= 0 {
        return errors.New("invalid amount")
    }

    // Low-level: HTTP client setup
    client := &http.Client{Timeout: 10 * time.Second}
    req, err := http.NewRequest("POST", "https://api.payment.com/charge", nil)
    if err != nil {
        return err
    }
    req.Header.Set("Authorization", "Bearer "+os.Getenv("API_KEY"))
    req.Header.Set("Content-Type", "application/json")

    // Low-level: JSON marshaling
    body := map[string]interface{}{
        "order_id": orderID,
        "amount":   amount,
    }
    jsonBody, err := json.Marshal(body)
    if err != nil {
        return err
    }
    req.Body = io.NopCloser(bytes.NewReader(jsonBody))

    // Low-level: HTTP call
    resp, err := client.Do(req)
    if err != nil {
        return err
    }
    defer resp.Body.Close()

    // High-level: logging
    log.Printf("Payment processed for order %s", orderID)
    return nil
}
```

**Review Findings:**
- 🟡 **Readability Debt**: Mixed abstraction levels (business + HTTP details)
- 🟡 **Readability Debt**: Function not storified (hard to see flow)

### After (No Debt)
```go
func ProcessPayment(orderID OrderID, amount Amount) error {
    if err := validatePayment(orderID, amount); err != nil {
        return err
    }

    if err := chargePaymentGateway(orderID, amount); err != nil {
        return err
    }

    logPaymentSuccess(orderID)
    return nil
}

func validatePayment(orderID OrderID, amount Amount) error {
    // Validation logic only (already validated by types, but could have business rules)
    return nil
}

func chargePaymentGateway(orderID OrderID, amount Amount) error {
    // HTTP client logic encapsulated
    client := newPaymentClient()
    return client.Charge(orderID, amount)
}

func logPaymentSuccess(orderID OrderID) {
    log.Printf("Payment processed for order %s", orderID)
}
```

---

## Example 3: Horizontal Layers → Vertical Slices

### Before (Design Debt 🔴)
```
project/
├── domain/
│   └── user.go
├── service/
│   └── user_service.go
├── repository/
│   └── user_repository.go
└── handler/
    └── user_handler.go
```

**Review Finding:**
- 🔴 **Design Debt**: Horizontal layering instead of vertical slices
- Impact: User feature changes require touching 4 different directories

### After (No Debt)
```
project/
└── user/
    ├── user.go           # Domain type
    ├── service.go        # Business logic
    ├── repository.go     # Persistence
    ├── handler.go        # HTTP
    └── user_test.go
```

**Benefits:**
- All user-related code in one place
- Easy to understand complete feature
- Independent testing/deployment

---

## Example 4: Generic Naming

### Before (Readability Debt 🟡)
```go
package common

type DataManager struct {
    store Storage
}

func (m *DataManager) ProcessData(data interface{}) (interface{}, error) {
    // ...
}

func HandleRequest(ctx context.Context, data map[string]interface{}) error {
    // ...
}
```

**Review Findings:**
- 🟡 **Readability Debt**: Generic package name (`common`)
- 🟡 **Readability Debt**: Vague type name (`DataManager`)
- 🟡 **Readability Debt**: Meaningless function names (`ProcessData`, `HandleRequest`)

### After (No Debt)
```go
package user

type Service struct {
    repo Repository
}

func (s *Service) Create(ctx context.Context, u User) error {
    // ...
}

func (s *Service) Authenticate(ctx context.Context, credentials Credentials) (Token, error) {
    // ...
}
```

---

## Example 5: Testing Anti-Patterns

### Before (Design Debt 🔴)
```go
package user  // Same package

// Testing private function
func TestValidateEmailInternal(t *testing.T) {
    assert.True(t, validateEmailInternal("test@example.com"))
}

// Heavy mocking
func TestCreateUser(t *testing.T) {
    mockRepo := &MockRepository{}
    mockEmailer := &MockEmailer{}

    mockRepo.On("Save", mock.Anything).Return(nil)
    mockEmailer.On("Send", mock.Anything).Return(nil)

    svc := &UserService{
        Repo:    mockRepo,
        Emailer: mockEmailer,
    }

    err := svc.CreateUser("123", "test@example.com")
    assert.NoError(t, err)

    mockRepo.AssertExpectations(t)
}

// Flaky with time.Sleep
func TestAsyncOperation(t *testing.T) {
    go doAsyncWork()
    time.Sleep(100 * time.Millisecond)  // ❌ Flaky
    assert.True(t, workCompleted)
}
```

**Review Findings:**
- 🔴 **Design Debt**: Testing private methods
- 🔴 **Design Debt**: Using mocks instead of real implementations
- 🔴 **Design Debt**: Flaky test with time.Sleep

### After (No Debt)
```go
package user_test  // External package

// Test public API only
func TestService_CreateUser(t *testing.T) {
    // Use real implementations
    repo := user.NewInMemoryRepository()
    emailer := user.NewTestEmailer()

    svc, err := user.NewUserService(repo, emailer)
    require.NoError(t, err)

    id, _ := user.NewUserID("123")
    email, _ := user.NewEmail("test@example.com")

    u := user.User{ID: id, Email: email}
    err = svc.CreateUser(context.Background(), u)

    assert.NoError(t, err)

    // Verify via public API
    retrieved, err := svc.GetUser(context.Background(), id)
    assert.NoError(t, err)
    assert.Equal(t, email, retrieved.Email)
}

// No flakiness with channels
func TestAsyncOperation(t *testing.T) {
    done := make(chan struct{})

    go func() {
        doAsyncWork()
        close(done)
    }()

    select {
    case <-done:
        // Success
    case <-time.After(1 * time.Second):
        t.Fatal("timeout waiting for async work")
    }
}
```

---

## Example 6: Complete Commit Review Output

### Scenario
Developer adds user authentication feature with some design issues.

### Review Output
```
📋 COMMIT READINESS SUMMARY

✅ Linter: Passed (0 issues)
✅ Tests: 87% coverage (5 new types, 23 test cases)
⚠️  Design Review: 5 findings (see below)

🎯 COMMIT SCOPE
Modified:
- user/service.go (+120, -30 lines)
- user/auth.go (new file, +85 lines)

Added:
- user/user_id.go (new type: UserID)
- user/password.go (new type: Password)

Tests:
- user/service_test.go (+95 lines)
- user/auth_test.go (new, +140 lines)

⚠️  DESIGN REVIEW FINDINGS

🔴 DESIGN DEBT (Recommended to fix):

1. user/service.go:67 - Primitive obsession on session token
   Current: func CreateSession(userID UserID) (string, error)
   Better:  func CreateSession(userID UserID) (SessionToken, error)
   Why: Session tokens should be validated types to prevent empty/invalid tokens
   Fix: Use @code-designing to create SessionToken type with validation

2. user/auth.go:34 - Non-self-validating type
   Current:
     type Authenticator struct {
         HashCost int  // Could be invalid
     }
   Better:
     func NewAuthenticator(hashCost int) (*Authenticator, error) {
         if hashCost < 4 || hashCost > 31 {
             return nil, errors.New("invalid hash cost")
         }
         // ...
     }
   Why: Constructor should validate, methods shouldn't need defensive checks
   Fix: Use @code-designing to add validating constructor

🟡 READABILITY DEBT (Consider fixing):

3. user/auth.go:89 - Mixed abstraction levels in Authenticate()
   Function mixes high-level auth flow with low-level bcrypt details
   Why: Harder to understand auth logic at a glance
   Fix: Use @refactoring to extract password comparison to separate function

4. user/service.go:45 - Function could be storified better
   Current: validateAndCreateUser() does validation + creation in one function
   Better: Split into validateUser() and createUser() for clarity
   Why: Single responsibility, easier to test each part
   Fix: Use @refactoring to split responsibilities

🟢 POLISH OPPORTUNITIES:

5. user/auth.go:12 - Less idiomatic naming
   Current: ComparePasswordWithHash
   Better:  PasswordMatches
   Why: More concise, Go-style naming

📝 BROADER CONTEXT:
While reviewing user/service.go, noticed email is still stored as string type
(line 23). Consider refactoring to use Email type consistently across the file
for better type safety (similar to UserID change in this commit).

💡 SUGGESTED COMMIT MESSAGE
Add user authentication with self-validating types

- Introduce UserID and Password self-validating types
- Implement Authenticator with bcrypt password hashing
- Add CreateSession and Authenticate methods
- Achieve 87% test coverage with real bcrypt testing

Follows primitive obsession principles with type-safe IDs and passwords.

────────────────────────────────────────

Would you like to:
1. Commit as-is (5 design findings remain)
2. Fix design debt only (🔴 items 1-2), then commit
3. Fix design + readability debt (🔴🟡 items 1-4), then commit
4. Fix all findings including polish (🔴🟡🟢 all items), then commit
5. Expand scope to refactor email type throughout file, then commit
```
