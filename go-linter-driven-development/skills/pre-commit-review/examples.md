# Pre-Commit Review Examples

Real-world examples of design review findings with before/after comparisons.

## Example 0: Detection Workflow

Shows how the pre-commit-review skill analyzes code step-by-step using LLM reasoning.

### Input: user/service.go

```go
package user

type UserService struct {
    Repo Repository
}

func (s *UserService) CreateUser(id string, email string) error {
    // Validate ID
    if id == "" {
        return errors.New("empty id")
    }

    // Validate email
    if !strings.Contains(email, "@") {
        return errors.New("invalid email")
    }

    // Open DB
    db, err := sql.Open("postgres", connStr)
    if err != nil {
        return err
    }
    defer db.Close()

    // Build query
    query := "INSERT INTO users (id, email) VALUES (?, ?)"
    _, err = db.Exec(query, id, email)
    if err != nil {
        return err
    }

    // Send email
    _ = sendEmail(email, "Welcome!")

    return nil
}
```

### LLM Analysis Step-by-Step

**Step 1: Apply Primitive Obsession Check (reference.md #1)**

Questions LLM asks:
- Q: Are primitives being validated?
- A: Yes - 'id' string validated at line 9, 'email' string validated at line 14

- Q: Is same validation repeated elsewhere?
- A: [Uses Grep tool to search codebase]
  - Found in handler.go:23 (same id validation)
  - Found in repository.go:45 (same email validation)

- Q: Would types add value beyond validation?
- A: Yes
  - Email: Complex validation pattern, domain concept
  - UserID: Validation scattered, type safety benefit

- Q: Calculate juiciness score (see reference.md):
  ```
  UserID:
  - Validation in 3 places (+1)
  - Simple empty check (+0)
  - Used in 8 locations (+2)
  Score: 3/10 → MEDIUM priority

  Email:
  - Validation in 3 places (+1)
  - Regex validation possible (+3)
  - Domain/LocalPart methods (+2)
  - Used in 8 locations (+2)
  Score: 8/10 → HIGH priority
  ```

**Finding identified:**
```
🔴 Design Debt: Primitive obsession
- string id → UserID type (MEDIUM juiciness)
- string email → Email type (HIGH juiciness)
```

---

**Step 2: Apply Storifying Check (reference.md #2)**

Questions LLM asks:
- Q: Does function read like a story?
- A: No - mixes abstraction levels:
  - Lines 7-16: High-level validation
  - Lines 18-23: Low-level DB connection setup
  - Lines 25-31: SQL implementation details
  - Lines 33-34: High-level notification

- Q: Can I explain flow in 3-5 clear steps?
- A: Should be: validateUser() → saveUser() → notifyUser()
  But currently mixes infrastructure and business logic

**Finding identified:**
```
🟡 Readability Debt: Function not storified
Mixed abstraction levels in CreateUser
Should extract: validateUser(), saveUser(), notifyUser()
```

---

**Step 3: Apply Self-Validating Types Check (reference.md #3)**

Questions LLM asks:
- Q: Do methods check if struct fields are nil/invalid?
- A: No checks in this method, but...

- Q: Could UserService.Repo be nil?
- A: Yes - struct can be created without validation
  ```go
  svc := &UserService{} // Repo is nil!
  svc.CreateUser(...) // Will panic if we use Repo
  ```

- Q: Is there a constructor with validation?
- A: [Searches codebase] No NewUserService constructor found

**Finding identified:**
```
🔴 Design Debt: Non-self-validating type
UserService can be created with nil Repo
Need NewUserService constructor
```

---

**Step 4: Apply Design Bugs Check (reference.md #8)**

Questions LLM asks:
- Q: Potential nil dereferences?
- A: Not obvious in this function (but found UserService.Repo issue above)

- Q: Are errors ignored?
- A: YES! Line 34: `_ = sendEmail(email, "Welcome!")`
  Silent failure, no visibility into delivery failures

- Q: Resources cleaned up?
- A: Yes, defer db.Close() at line 23 ✓

- Q: Context propagated?
- A: No ctx parameter, but no downstream calls needing it

**Finding identified:**
```
🐛 Bug: Ignored error
Line 34: _ = sendEmail() silently ignores failure
Should at least log the error
```

---

**Step 5: Apply Other Checks**

- Abstraction Levels (#4): Already covered in storifying
- Architecture (#5): Single file, can't assess pattern
- Naming (#6): Names are clear and idiomatic ✓
- Testing (#7): No test file in scope
- Comment Quality: Missing (no package docs, no function docs)
- File Structure: Single type, reasonable size ✓

---

### Analysis Complete - Categorize & Prioritize

**Bugs (Priority 1 - Fix immediately):**
1. Ignored error at line 34

**Design Debt (Priority 2 - Fix before commit):**
2. Primitive obsession: string email (HIGH juiciness: 8/10)
3. Primitive obsession: string id (MEDIUM juiciness: 3/10)
4. Non-self-validating: UserService

**Readability Debt (Priority 3 - Improves maintainability):**
5. Not storified: CreateUser function

---

### Output Report

```
📊 CODE REVIEW REPORT
Generated: 2025-11-09 15:45:00
Scope: user/service.go (1 file, 40 lines)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total findings: 5
🐛 Bugs: 1 (fix immediately)
🔴 Design Debt: 3 (fix before commit recommended)
🟡 Readability Debt: 1 (improves maintainability)
🟢 Polish: 0

Estimated fix effort: 50 minutes total
  - Critical (bugs + high juiciness design): 25 min
  - Recommended (medium design + readability): 25 min

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🐛 BUGS (1) - FIX IMMEDIATELY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Ignored error
   Location: user/service.go:34
   Code: _ = sendEmail(email, "Welcome!")

   Issue: Email sending failure silently ignored
   Impact: No visibility into delivery failures, hard to debug

   Fix: Log error at minimum:
     if err := sendEmail(email, "Welcome!"); err != nil {
       log.Printf("failed to send welcome email: %v", err)
     }

   Better: Return error if critical:
     if err := sendEmail(email, "Welcome!"); err != nil {
       return fmt.Errorf("send welcome email: %w", err)
     }

   Effort: 2 min

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 DESIGN DEBT (3) - FIX BEFORE COMMIT RECOMMENDED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Primitive obsession: string email (HIGH juiciness: 8/10)
   Locations: Line 6, 14, 28, 34
   Also found in: handler.go:23, repository.go:45

   Juiciness Score: 8/10
   - Validation in 3 places (+1)
   - Complex regex validation possible (+3)
   - Methods: Domain(), LocalPart() (+2)
   - Used in 8 locations (+2)

   Current:
     func CreateUser(id string, email string) error {
       if !strings.Contains(email, "@") {
         return errors.New("invalid email")
       }
       // ...
     }

   Better:
     type Email string

     func ParseEmail(s string) (Email, error) {
       if !emailRegex.MatchString(s) {
         return "", fmt.Errorf("invalid email: %s", s)
       }
       return Email(s), nil
     }

     func (e Email) Domain() string { /* ... */ }
     func (e Email) LocalPart() string { /* ... */ }
     func (e Email) String() string { return string(e) }

     func CreateUser(id string, email Email) error {
       // No validation needed, guaranteed valid
     }

   Why: Type safety, centralized validation, prevents invalid emails
   Fix: Use @code-designing skill → Create Email type
   Effort: 20 min

2. Primitive obsession: string id (MEDIUM juiciness: 3/10)
   Locations: Line 6, 9, 28
   Also found in: handler.go:23, repository.go:45

   Juiciness Score: 3/10
   - Validation in 3 places (+1)
   - Simple empty check (+0)
   - Used in 8 locations (+2)

   Note: Borderline case. Judgment call on whether to create type.

   Better:
     type UserID string

     func ParseUserID(s string) (UserID, error) {
       if s == "" {
         return "", errors.New("empty user id")
       }
       return UserID(s), nil
     }

   Why: Centralizes validation, type safety
   Fix: Use @code-designing skill → Create UserID type
   Effort: 10 min

3. Non-self-validating type: UserService
   Location: user/service.go:4

   Issue: UserService.Repo is public, can be nil
   No constructor to validate dependencies

   Current:
     type UserService struct {
       Repo Repository  // Can be nil!
     }

     svc := &UserService{}  // Invalid state allowed

   Better:
     type UserService struct {
       repo Repository  // Private
     }

     func NewUserService(repo Repository) (*UserService, error) {
       if repo == nil {
         return nil, errors.New("repo required")
       }
       return &UserService{repo: repo}, nil
     }

     func (s *UserService) CreateUser(id string, email Email) error {
       // No nil checks needed - constructor guarantees validity
       return s.repo.Save(...)
     }

   Why: Impossible to create invalid service, eliminates defensive checks
   Fix: Use @code-designing skill → Add constructor
   Effort: 10 min

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟡 READABILITY DEBT (1) - IMPROVES MAINTAINABILITY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Function not storified: CreateUser
   Location: user/service.go:6-36

   Issue: Mixes 3 abstraction levels:
   - Lines 7-16: High-level validation
   - Lines 18-31: Low-level DB connection/SQL
   - Lines 33-34: High-level notification

   Flow not clear at a glance, hard to test pieces independently.

   Better:
     func CreateUser(id string, email Email) error {
       if err := validateUser(id, email); err != nil {
         return err
       }

       if err := saveUser(id, email); err != nil {
         return err
       }

       if err := notifyUser(email); err != nil {
         return err
       }

       return nil
     }

     func validateUser(id string, email Email) error { /* ... */ }
     func saveUser(id string, email Email) error { /* ... */ }
     func notifyUser(email Email) error { /* ... */ }

   Why: Reads like a story, testable pieces, clear intent
   Fix: Use @refactoring skill → Storifying pattern
   Effort: 15 min

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RECOMMENDATIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Priority 1: Fix immediately (2 min)
  ☐ Fix ignored error (log or return)

Priority 2: Fix before commit (40 min)
  ☐ Create Email type (HIGH juiciness) @code-designing
  ☐ Create UserID type (MEDIUM juiciness) @code-designing
  ☐ Add NewUserService constructor @code-designing

Priority 3: Improve maintainability (15 min)
  ☐ Storify CreateUser function @refactoring

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SKILLS TO USE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@code-designing: For creating Email, UserID types and NewUserService
@refactoring: For storifying CreateUser function
Manual: For fixing ignored error (simple change)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
END OF REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

This example demonstrates how the reviewer skill applies the complete checklist from reference.md systematically, using LLM reasoning to detect issues that linters cannot catch.

---

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
