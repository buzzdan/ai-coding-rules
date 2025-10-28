# Type Design Subset for Refactoring

Quick reference for type design principles when refactoring.
For complete type design guidance, see @code-designing skill.

## When Refactoring Reveals Need for Types

### Primitive Obsession Signal
During refactoring, if you find:
- Validation repeated across multiple functions
- Complex logic operating on primitives (string, int, float)
- Parameters passed around without type safety

→ Create a self-validating type

### Pattern: Self-Validating Type
```go
type TypeName underlyingType

func NewTypeName(input underlyingType) (TypeName, error) {
    // Validate
    if /* invalid */ {
        return zero, errors.New("why invalid")
    }
    return TypeName(input), nil
}

// Add methods if behavior needed
func (t TypeName) SomeMethod() result {
    // Type-specific logic
}
```

## Type Design Checklist

When creating types during refactoring:

- [ ] **Constructor validates** - Check in New* function
- [ ] **Fields are private** - Prevent invalid state
- [ ] **Methods trust validity** - No nil checks
- [ ] **Type has behavior** - Not just data container
- [ ] **Type in own file** - If it has logic

## Examples

### Example 1: Port Validation
```go
// Before refactoring - Validation scattered
func StartServer(port int) error {
    if port <= 0 || port >= 9000 {
        return errors.New("invalid port")
    }
    // ...
}

func ConnectTo(host string, port int) error {
    if port <= 0 || port >= 9000 {
        return errors.New("invalid port")
    }
    // ...
}

// After refactoring - Self-validating type
type Port int

func NewPort(p int) (Port, error) {
    if p <= 0 || p >= 9000 {
        return 0, errors.New("port must be 1-8999")
    }
    return Port(p), nil
}

func StartServer(port Port) error {
    // No validation needed
    // ...
}

func ConnectTo(host string, port Port) error {
    // No validation needed
    // ...
}
```

### Example 2: Parser Complexity
```go
// Before refactoring - One complex Parser
type Parser struct {
    // Too many responsibilities
}

func (p *Parser) Parse(input string) (Result, error) {
    // 100+ lines parsing headers, path, body, etc.
}

// After refactoring - Separate types by role
type HeaderParser struct { /* ... */ }
type PathParser struct { /* ... */ }
type BodyParser struct { /* ... */ }

func (p *HeaderParser) Parse(input string) (Header, error) {
    // Focused logic for headers only
}

func (p *PathParser) Parse(input string) (Path, error) {
    // Focused logic for path only
}

func (p *BodyParser) Parse(input string) (Body, error) {
    // Focused logic for body only
}
```

## Quick Decision: Create Type or Extract Function?

### Create Type When:
- Logic operates on a primitive
- Validation is repeated
- Type represents domain concept
- Behavior is cohesive

### Extract Function When:
- Logic is procedural (no state needed)
- Different abstraction level
- One-time operation
- No validation required

## Integration with Refactoring

After creating types during refactoring:
1. Run tests - Ensure they pass
2. Run linter - Should reduce complexity
3. Consider @code-designing - Validate type design
4. Update tests - Ensure new types have 100% coverage

## File Organization

When creating types during refactoring:
```
package/
├── original.go          # Original file
├── new_type.go          # New type in own file (if has logic)
└── original_test.go     # Tests
```

---

For complete type design principles, see @code-designing skill.
