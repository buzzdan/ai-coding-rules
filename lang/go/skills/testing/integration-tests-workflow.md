**Purpose**: Middle rungs — each adds one real layer; test the seams and emergent behaviors that layer brings

1. **Identify integration points** - Where packages/components interact
2. **Choose dependencies** - Prefer: in-memory > binary > test-containers
3. **Write tests** - In `pkg_test` or `integration_test.go` with build tags
4. **Test workflows** - Cover happy path and error scenarios across boundaries
5. **Use real or testutils implementations** - Avoid heavy mocking

**File organization:**
```go
//go:build integration

package user_test

// Test Service + Repository + real/mock dependencies
```

See reference.md for integration test patterns with dependencies.
