---
name: refactoring
description: Linter-driven refactoring patterns to reduce complexity and improve code quality. Use when linter fails with complexity issues (cyclomatic, cognitive, maintainability) or when code feels hard to read/maintain. Applies storifying, type extraction, and function extraction patterns.
---

# Refactoring

Linter-driven refactoring patterns to reduce complexity and improve code quality.

## When to Use
- **Automatically invoked** by @linter-driven-development when linter fails
- **Automatically invoked** by @pre-commit-review when design issues detected
- **Complexity failures**: cyclomatic, cognitive, maintainability index
- **Architectural failures**: noglobals, gochecknoinits, gochecknoglobals
- **Design smell failures**: dupl (duplication), goconst (magic strings), ineffassign
- Functions > 50 LOC or nesting > 2 levels
- Mixed abstraction levels in functions
- Manual invocation when code feels hard to read/maintain

**IMPORTANT**: This skill operates autonomously - no user confirmation needed during execution

## Learning Resources

Choose your learning path:
- **Quick Start**: Use the patterns below for common refactoring cases
- **Complete Reference**: See [reference.md](./reference.md) for full decision tree and all patterns
- **Real-World Examples**: See [examples.md](./examples.md) to learn the refactoring thought process
  - [Example 1](./examples.md#example-1-storifying-mixed-abstractions-and-extracting-logic-into-leaf-types): Storifying and extracting a single leaf type
  - [Example 2](./examples.md#example-2-primitive-obsession-with-multiple-types-and-storifying-switch-statements): Primitive obsession with multiple types and switch elimination

## Analysis Phase (Automatic)

Before applying any refactoring patterns, the skill automatically analyzes the context:

### System Context Analysis
```
AUTOMATICALLY ANALYZE:
1. Find all callers of the failing function
2. Identify which flows/features depend on it
3. Determine primary responsibility
4. Check for similar functions revealing patterns
5. Spot potential refactoring opportunities
```

### Type Discovery
Proactively identify hidden types in the code:

```
POTENTIAL TYPES TO DISCOVER:
1. Data being parsed from strings → Parse* types
   Example: ParseCommandResult(), ParseLogEntry()

2. Scattered validation logic → Validated types
   Example: Email, Port, IPAddress types

3. Data that always travels together → Aggregate types
   Example: UserCredentials, ServerConfig

4. Complex conditions → State/status types
   Example: DeploymentStatus with IsReady(), CanProceed()

5. Repeated string manipulation → Types with methods
   Example: FilePath with Dir(), Base(), Ext()
```

### Analysis Output
The analysis produces a refactoring plan identifying:
- Function's role in the system
- Potential domain types to extract
- Recommended refactoring approach
- Expected complexity reduction

## Refactoring Signals

### Linter Failures
**Complexity Issues:**
- **Cyclomatic Complexity**: Too many decision points → Extract functions, simplify logic
- **Cognitive Complexity**: Hard to understand → Storifying, reduce nesting
- **Maintainability Index**: Hard to maintain → Break into smaller pieces

**Architectural Issues:**
- **noglobals/gochecknoglobals**: Global variable usage → Dependency rejection pattern
- **gochecknoinits**: Init function usage → Extract initialization logic
- **Static/singleton patterns**: Hidden dependencies → Inject dependencies

**Design Smells:**
- **dupl**: Code duplication → Extract common logic/types
- **goconst**: Magic strings/numbers → Extract constants or types
- **ineffassign**: Ineffective assignments → Simplify logic

### Code Smells
- Functions > 50 LOC
- Nesting > 2 levels
- Mixed abstraction levels
- Unclear flow/purpose
- Primitive obsession
- Global variable access scattered throughout code

## Workflow (Automatic)

### 1. Receive Linter Failures
Automatically receive failures from @linter-driven-development:
```
user/service.go:45:1: cyclomatic complexity 15 of func `CreateUser` is high (> 10)
user/handler.go:23:1: cognitive complexity 25 of func `HandleRequest` is high (> 15)
```

### 2. Automatic Root Cause Analysis
The skill automatically diagnoses each failure:
- Does this code read like a story? → Apply storifying
- Can this be broken into smaller pieces? → Extract functions/types
- Does logic run on primitives? → Check for primitive obsession
- Is function long due to switch statement? → Extract case handlers

### 3. Automatic Pattern Application
Applies patterns in priority order without user intervention:
- **Early Returns**: Try first (least invasive)
- **Extract Function**: Break up complexity
- **Storifying**: Improve abstraction levels
- **Extract Type**: Create domain types (if juicy)
- **Switch Extraction**: Categorize cases

### 4. Automatic Verification Loop
- Re-run linter automatically
- If still failing, try next pattern
- Continue until linter passes
- Report final results

## Automation Flow

This skill operates completely autonomously once invoked:

### Automatic Iteration Loop
```
AUTOMATED PROCESS:
1. Receive trigger:
   - From @linter-driven-development (linter failures)
   - From @pre-commit-review (design debt/readability debt)
2. Apply refactoring pattern (start with least invasive)
3. Run linter immediately (no user confirmation)
4. If linter still fails OR review finds more issues:
   - Try next pattern in priority order
   - Repeat until both linter and review pass
5. If patterns exhausted and still failing:
   - Report what was tried
   - Suggest file splitting or architectural changes
```

### Pattern Priority Order
Apply patterns based on failure type:

**For Complexity Failures** (cyclomatic, cognitive, maintainability):
```
1. Early Returns → Reduce nesting quickly
2. Extract Function → Break up long functions
3. Storifying → Improve abstraction levels
4. Extract Type → Create domain types (only if "juicy")
5. Switch Extraction → Categorize switch cases
```

**For Architectural Failures** (noglobals, singletons):
```
1. Dependency Rejection → Incremental bottom-up approach
2. Extract Type with dependency injection
3. Push global access up call chain one level
4. Iterate until globals only at entry points (main, handlers)
```

**For Design Smells** (dupl, goconst):
```
1. Extract Type → For repeated values or validation
2. Extract Function → For code duplication
3. Extract Constant → For magic strings/numbers
```

### No Manual Intervention
- **NO** asking for confirmation between patterns
- **NO** waiting for user input
- **NO** manual linter runs
- **AUTOMATIC** progression through patterns
- **ONLY** report results at the end

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
**Signal**: Complex logic operating on primitives OR unstructured data needing organization

#### Juiciness Test v2 - When to Create Types

**BEHAVIORAL JUICINESS** (rich behavior):
- ✅ Complex validation rules (regex, ranges, business rules)
- ✅ Multiple meaningful methods (≥2 methods)
- ✅ State transitions or transformations
- ✅ Format conversions (different representations)

**STRUCTURAL JUICINESS** (organizing complexity):
- ✅ Parsing unstructured data into fields
- ✅ Grouping related data that travels together
- ✅ Making implicit structure explicit
- ✅ Replacing map[string]interface{} with typed fields

**USAGE JUICINESS** (simplifies code):
- ✅ Used in multiple places
- ✅ Significantly simplifies calling code
- ✅ Makes tests cleaner and more focused

**Score**: Need "yes" in at least ONE category to create the type

#### Examples of Juicy vs Non-Juicy Types

```go
// ❌ NOT JUICY - Don't create type
func ValidateUserID(id string) error {
    if id == "" {
        return errors.New("empty id")
    }
    return nil
}
// Just use: if userID == ""

// ✅ JUICY (Behavioral) - Complex validation
type Email string

func ParseEmail(s string) (Email, error) {
    if s == "" {
        return "", errors.New("empty email")
    }
    if !emailRegex.MatchString(s) {
        return "", errors.New("invalid format")
    }
    if len(s) > 255 {
        return "", errors.New("too long")
    }
    return Email(s), nil
}

func (e Email) Domain() string { /* extract domain */ }
func (e Email) LocalPart() string { /* extract local */ }
func (e Email) String() string { return string(e) }

// ✅ JUICY (Structural) - Parsing complex data
type CommandResult struct {
    FailedFiles  []string
    SuccessFiles []string
    Message      string
    ExitCode     int
    Warnings     []string
}

func ParseCommandResult(output string) (CommandResult, error) {
    // Parse unstructured output into structured fields
    // Making implicit structure explicit
}

// ✅ JUICY (Mixed) - Both behavior and structure
type ServiceEndpoint struct {
    host string
    port Port
}

func ParseEndpoint(s string) (ServiceEndpoint, error) {
    // Parse "host:port/path" format
}

func (e ServiceEndpoint) URL() string { }
func (e ServiceEndpoint) IsSecure() bool { }
func (e ServiceEndpoint) WithPath(path string) string { }
```

**⚠️ Warning Signs of Over-Engineering:**
- Type with only one trivial method
- Simple validation (just empty check)
- Type that's just a wrapper without behavior
- Good variable naming would be clearer

**→ See [Example 2](./examples.md#first-refactoring-attempt-the-over-abstraction-trap)** for complete case study.

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

### Pattern 6: Dependency Rejection (Architectural Refactoring)
**Signal**: noglobals linter fails OR global/singleton usage detected

**Goal**: Create "islands of clean code" by incrementally pushing dependencies up the call chain

**Strategy**: Work from bottom-up, rejecting dependencies one level at a time
- DON'T do massive refactoring all at once
- Start at deepest level (furthest from main)
- Extract clean type with dependency injected
- Push global access up one level
- Repeat until global only at entry points

**Quick Example**:
```go
// ❌ Before - Global accessed deep in code
func PublishEvent(event Event) error {
    conn, err := nats.Connect(env.Configs.NATsAddress)
    // ... complex logic
}

// ✅ After - Dependency rejected up one level
type EventPublisher struct {
    natsAddress string  // injected, not global
}

func NewEventPublisher(natsAddress string) *EventPublisher {
    return &EventPublisher{natsAddress: natsAddress}
}

func (p *EventPublisher) Publish(event Event) error {
    conn, err := nats.Connect(p.natsAddress)
    // ... same logic, now testable
}

// Caller pushed up (closer to main)
func SetupMessaging() *EventPublisher {
    return NewEventPublisher(env.Configs.NATsAddress)  // Global only here
}
```

**Result**: EventPublisher is now 100% testable without globals

**Key Principles**:
- **Incremental**: One type at a time, one level at a time
- **Bottom-up**: Start at deepest code, work toward main
- **Pragmatic**: Accept globals at entry points (main, handlers)
- **Testability**: Each extracted type is an island (testable in isolation)

**→ See [Example 3](./examples.md#example-3-dependency-rejection-pattern) for complete case study with config access patterns**

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

## Testing Integration

### Automatic Test Creation
When creating new types or extracting functions during refactoring:

**ALWAYS invoke @testing skill** to write tests for:
- **Isolated types**: Types with injected dependencies (testable islands)
- **Value object types**: Types that may depend on other value objects but are still isolated
- **Extracted functions**: New functions created during refactoring
- **Parse functions**: Functions that transform unstructured data

### Island of Clean Code Definition

A type is an "island of clean code" if:
- ✅ Dependencies are explicit (injected via constructor)
- ✅ No global or static dependencies
- ✅ Can be tested in isolation
- ✅ Has 100% testable public API

**Examples of testable islands:**
- `NATSClient` with injected `natsAddress` string (no other dependencies)
- `Email` type with validation logic (no dependencies)
- `ServiceEndpoint` that uses `Port` value object (both are testable islands)
- `OrderService` with injected `Repository` and `EventPublisher` (all testable)

**Note**: Islands can depend on other value objects and still be isolated!

### Workflow
```
REFACTORING → TESTING:
1. Extract type during refactoring
2. Immediately invoke @testing skill
3. @testing skill writes appropriate tests:
   - Table-driven tests for simple scenarios
   - Testify suites for complex infrastructure
   - Integration tests for orchestrating types
4. Verify tests pass
5. Continue refactoring
```

### Testing Delegation
- **Refactoring skill**: Makes code testable (creates islands)
- **@testing skill**: Writes all tests (structure, patterns, coverage)

**→ See @testing skill for test structure, patterns, and guidelines**

## Stopping Criteria

### When to Stop Refactoring

**STOP when ALL of these are met:**
```
✅ Linter passes
✅ All functions < 50 LOC
✅ Nesting ≤ 2 levels
✅ Code reads like a story
✅ No more "juicy" abstractions to extract
```

### Don't Over-Refactor

**Warning Signs of Over-Engineering:**
- Creating types with only one method
- Functions that just call another function
- More abstraction layers than necessary
- Code becomes harder to understand
- Diminishing returns on complexity reduction

**Pragmatic Approach:**
```
IF linter passes AND code is readable:
    STOP - Don't extract more
EVEN IF you could theoretically extract more:
    STOP - Avoid abstraction bloat
```

### Example Stopping Decision
```
Current State:
- Function: 45 LOC (was 120) ✅
- Complexity: 8 (was 25) ✅
- Nesting: 2 levels (was 4) ✅
- Created 2 juicy types (Email, PhoneNumber) ✅

Could extract UserID type but:
- Only validation is "not empty" ❌
- No other methods needed ❌
- Good naming is sufficient ❌

Decision: STOP HERE - Goals achieved, avoid bloat
```

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
🔍 CONTEXT ANALYSIS

Function: CreateUser (user/service.go:45)
Role: Core user creation orchestration
Called by:
- api/handler.go:89 (HTTP endpoint)
- cmd/user.go:34 (CLI command)
- test/fixtures.go:123 (test fixtures)

Potential types spotted:
- Email: Complex validation logic scattered
- UserID: Generation and validation logic
- UserCreationRequest: Multiple related fields

🔧 REFACTORING APPLIED

✅ Patterns Successfully Applied:
1. Early Returns: Reduced nesting from 4 to 2 levels
2. Storifying: Extracted validate(), save(), notify()
3. Extract Type: Created Email and PhoneNumber types

❌ Patterns Tried but Insufficient:
- Extract Function alone: Still too complex, needed types

🎯 Types Created (with Juiciness Score):

✅ Email type (JUICY - Behavioral + Usage):
- Behavioral: ParseEmail(), Domain(), LocalPart() methods
- Usage: Used in 5+ places across codebase
- Island: Testable in isolation
- → Invoke @testing skill to write tests

✅ PhoneNumber type (JUICY - Behavioral):
- Behavioral: Parse(), Format(), CountryCode() methods
- Validation: Complex international format rules
- Island: Testable in isolation
- → Invoke @testing skill to write tests

❌ Types Considered but Rejected (NOT JUICY):
- UserID: Only empty check, good naming sufficient
- Status: Just string constants, enum adequate

🏗️ ARCHITECTURAL REFACTORING (if applicable)

Trigger: noglobals linter failure

Global Dependencies Identified:
- env.Configs.NATsAddress: Used in 12 places
- env.Configs.DBHost: Used in 8 places

Dependency Rejection Applied:
✅ Level 1 (Bottom): Created NATSClient with injected address
✅ Level 2 (Middle): Created OrderService using clean types
⬆️ Pushed env.Configs to: main() and HTTP handlers (2 locations)

Islands of Clean Code Created:
- messaging/nats_client.go: Ready for testing (isolated, injected deps)
- order/service.go: Ready for testing (isolated, injected deps)
→ Invoke @testing skill to write tests for these islands

Progress:
- Before: 20 global accesses scattered throughout
- After: 2 global accesses (entry points only)
- Islands created: 2 new testable types

📊 METRICS

Complexity Reduction:
- Cyclomatic: 18 → 7 ✅
- Cognitive: 25 → 8 ✅
- LOC: 120 → 45 ✅
- Nesting: 4 → 2 ✅

📝 FILES MODIFIED

Modified:
- user/service.go (+15, -75 lines)
- user/handler.go (+5, -20 lines)

Created (Islands of Clean Code):
- user/email.go (new, +45 lines) → Ready for @testing skill
- user/phone_number.go (new, +38 lines) → Ready for @testing skill

Next: Invoke @testing skill to write tests for new islands

✅ AUTOMATION COMPLETE

Stopping Criteria Met:
✅ Linter passes (0 issues)
✅ All functions < 50 LOC
✅ Max nesting = 2 levels
✅ Code reads like a story
✅ No more juicy abstractions

Ready for: @pre-commit-review phase
```

## Learning from Examples

For real-world refactoring case studies that show the complete thought process:

**[Example 1: Storifying Mixed Abstractions](./examples.md#example-1-storifying-mixed-abstractions-and-extracting-logic-into-leaf-types)**
- Transforms a 48-line fat function into lean orchestration + isolated type
- Shows how to extract `IPConfig` type for collection and validation logic
- Demonstrates creating testable islands of clean code

**[Example 2: Primitive Obsession with Multiple Types](./examples.md#example-2-primitive-obsession-with-multiple-types-and-storifying-switch-statements)**
- Transforms a 60-line function into a 7-line story by extracting 4 isolated types
- Shows the Type Alias Pattern for config-friendly types
- Demonstrates eliminating switch statement duplication
- Fixed misleading function name (`validateCIDR` → `alignCIDRArgs`)

**[Example 3: Dependency Rejection Pattern](./examples.md#example-3-dependency-rejection-pattern)**
- Incremental elimination of global config access (`env.Configs.NATsAddress`)
- Shows bottom-up approach: create clean islands one level at a time
- Demonstrates testability benefits of dependency injection
- Pragmatic stopping point: globals only at entry points

See [examples.md](./examples.md) for complete case studies with thought process.

## Integration with Other Skills

### Invoked By (Automatic Triggering)
- **@linter-driven-development**: Automatically invokes when linter fails (Phase 3)
- **@pre-commit-review**: Automatically invokes when design issues detected (Phase 4)

### Iterative Loop
```
1. Linter fails → invoke @refactoring
2. Refactoring complete → re-run linter
3. Linter passes → invoke @pre-commit-review
4. Review finds design debt → invoke @refactoring again
5. Refactoring complete → re-run linter
6. Repeat until both linter AND review pass
```

### Invokes (When Needed)
- **@code-designing**: When refactoring creates new types, validate design
- **@testing**: Automatically invoked to write tests for new types/functions
- **@pre-commit-review**: Validates design quality after linting passes

See [reference.md](./reference.md) for complete refactoring patterns and decision tree.
