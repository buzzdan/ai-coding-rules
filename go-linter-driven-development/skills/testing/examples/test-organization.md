# Test Organization and File Structure

## File Organization

### Basic Structure

```
user/
├── user.go
├── user_test.go          # Unit tests for user.go
├── service.go
├── service_test.go       # Unit tests for service.go
├── repository.go
└── repository_test.go    # Unit tests for repository.go
```

### With Integration and System Tests

```
project/
├── user/
│   ├── user.go
│   ├── user_test.go              # Unit tests (pkg_test)
│   ├── service.go
│   ├── service_test.go           # Unit tests (pkg_test)
│   └── integration_test.go       # Integration tests with //go:build integration
├── internal/
│   └── testutils/                # Reusable test infrastructure
│       ├── nats.go              # In-memory NATS server
│       ├── victoria.go          # Victoria Metrics binary management
│       └── httpserver/          # HTTP mock DSL
│           ├── server.go
│           └── server_test.go   # Test the infrastructure!
└── tests/                        # System tests (black box)
    ├── cli_test.go              # CLI testing via exec.Command
    └── api_test.go              # API testing via HTTP client
```

## Package Naming

### Use `pkg_test` for Unit Tests

```go
// ✅ External package - tests public API only
package user_test

import (
    "testing"
    "github.com/yourorg/project/user"
)

func TestService_CreateUser(t *testing.T) {
    // Test through public API
    svc, _ := user.NewUserService(repo, notifier)
    err := svc.CreateUser(ctx, testUser)
    // ...
}
```

### Avoid Same Package Testing

```go
// ❌ Same package - can test private methods (don't do this)
package user

import "testing"

func TestInternalValidation(t *testing.T) {
    // Testing private function - bad practice
    result := validateEmailInternal("test@example.com")
    // ...
}
```

## Build Tags for Integration Tests

### Using Build Tags

```go
//go:build integration

package user_test

import (
    "context"
    "testing"
    "myproject/internal/testutils"
)

func TestUserService_Integration(t *testing.T) {
    // Integration test with real dependencies
    natsServer, _ := testutils.RunNATsServer()
    defer natsServer.Shutdown()

    // Test with real NATS
    // ...
}
```

### Running Tests

```bash
# Run only unit tests (default - no build tags)
go test ./...

# Run unit + integration tests
go test -tags=integration ./...

# Run specific package integration tests
go test -tags=integration ./user

# Run system tests only
go test ./tests/...

# Run all tests
go test -tags=integration ./...
```

## Makefile/Taskfile Integration

### Taskfile.yml Example

```yaml
version: '3'

tasks:
  test:
    desc: Run unit tests
    cmds:
      - go test -v -race ./...

  test:integration:
    desc: Run integration tests
    cmds:
      - go test -v -race -tags=integration ./...

  test:system:
    desc: Run system tests
    cmds:
      - go test -v -race ./tests/...

  test:all:
    desc: Run all tests
    cmds:
      - task: test:integration
      - task: test:system

  test:coverage:
    desc: Run tests with coverage
    cmds:
      - go test -v -race -coverprofile=coverage.out ./...
      - go tool cover -html=coverage.out -o coverage.html
```

### Makefile Example

```makefile
.PHONY: test test-integration test-system test-all coverage

test:
	go test -v -race ./...

test-integration:
	go test -v -race -tags=integration ./...

test-system:
	go test -v -race ./tests/...

test-all: test-integration test-system

coverage:
	go test -v -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
```

## Test File Naming

### Unit Tests
- `*_test.go` - Standard test files
- Located next to the code being tested
- Use `pkg_test` package name

### Integration Tests
- `integration_test.go` or `*_integration_test.go`
- Use `//go:build integration` tag
- Can be in same directory or separate `integration/` folder
- Use `pkg_test` package name

### System Tests
- `*_test.go` in `tests/` directory at project root
- No build tags needed (separate directory)
- Use `tests` or `main_test` package name

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      - name: Run unit tests
        run: go test -v -race ./...

  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      - name: Run integration tests
        run: go test -v -race -tags=integration ./...

  system-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      - name: Build application
        run: go build -o myapp ./cmd/myapp
      - name: Run system tests
        run: go test -v -race ./tests/...
```

## testutils Package Structure

```
internal/testutils/
├── nats.go              # NATS in-memory server helpers
├── victoria.go          # Victoria Metrics binary management
├── prometheus.go        # Prometheus payload helpers
├── grpc_client_mock.go  # gRPC client mock with DSL
├── jrpc_server_mock.go  # JSON-RPC server mock with DSL
└── httpserver/          # HTTP mock server with DSL
    ├── server.go
    ├── server_test.go   # Test the infrastructure!
    ├── dsl.go
    └── README.md
```

## Key Principles

1. **Co-locate unit tests** - Next to the code being tested
2. **Use pkg_test package** - Forces public API testing
3. **Build tags for integration** - Keep unit tests fast by default
4. **Separate system tests** - In `tests/` directory
5. **Test your test infrastructure** - Treat testutils as production code
6. **Reusable infrastructure** - Share across all test levels
