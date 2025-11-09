# System Test Patterns

## Purpose

System tests are black-box tests that verify the entire application works correctly from an external perspective. They test via CLI or API, simulating real user interactions.

**Location**: `tests/` directory at project root (separate from package code)

## Principles

### Black Box Testing
- Test only via public interfaces (CLI, API)
- No access to internal packages
- Simulate real user behavior
- Test critical workflows end-to-end

### Independence in Go
- Strive for pure Go tests (no Docker required)
- Use in-memory mocks from `testutils`
- Binary dependencies when needed
- Avoid docker-compose in CI

## CLI Testing Patterns

### Pattern 1: Simple Command Execution

```go
// tests/cli_test.go
package tests

import (
    "os/exec"
    "strings"
    "testing"

    "github.com/stretchr/testify/require"
)

func TestCLI_Version(t *testing.T) {
    // Execute CLI command
    cmd := exec.Command("./myapp", "version")
    output, err := cmd.CombinedOutput()

    require.NoError(t, err)
    require.Contains(t, string(output), "myapp version")
}

func TestCLI_Help(t *testing.T) {
    cmd := exec.Command("./myapp", "--help")
    output, err := cmd.CombinedOutput()

    require.NoError(t, err)
    require.Contains(t, string(output), "Usage:")
}
```

### Pattern 2: CLI with In-Memory Mocks

```go
// tests/cli_metrics_test.go
package tests

import (
    "context"
    "os/exec"
    "testing"

    "github.com/stretchr/testify/require"
    "myproject/internal/testutils"
)

func TestCLI_MetricsIngest(t *testing.T) {
    // Start Victoria Metrics (Level 2 - binary)
    vmServer, err := testutils.RunVictoriaMetricsServer()
    require.NoError(t, err)
    defer vmServer.Shutdown()

    // Test CLI against real Victoria Metrics
    cmd := exec.Command("./myapp", "ingest",
        "--metrics-url", vmServer.WriteURL(),
        "--metric-name", "cli_test_metric",
        "--value", "100")

    output, err := cmd.CombinedOutput()
    require.NoError(t, err)
    require.Contains(t, string(output), "Metric ingested successfully")

    // Verify with helpers
    vmServer.ForceFlush(context.Background())
    results, err := testutils.QueryVictoriaMetrics(vmServer.QueryURL(), "cli_test_metric")
    require.NoError(t, err)
    require.Len(t, results, 1)
}
```

### Pattern 3: CLI with File System

```go
// tests/cli_config_test.go
package tests

import (
    "os"
    "os/exec"
    "path/filepath"
    "testing"

    "github.com/stretchr/testify/require"
)

func TestCLI_ConfigFile(t *testing.T) {
    // Create temp directory
    tempDir := t.TempDir()
    configPath := filepath.Join(tempDir, "config.yaml")

    // Write config file
    configContent := `
server:
  port: 8080
  host: localhost
`
    err := os.WriteFile(configPath, []byte(configContent), 0644)
    require.NoError(t, err)

    // Test CLI with config file
    cmd := exec.Command("./myapp", "start", "--config", configPath, "--dry-run")
    output, err := cmd.CombinedOutput()

    require.NoError(t, err)
    require.Contains(t, string(output), "Server would start on localhost:8080")
}
```

## API Testing Patterns

### Pattern 1: HTTP API with In-Memory Mocks

```go
// tests/api_test.go
package tests

import (
    "bytes"
    "encoding/json"
    "io"
    "net/http"
    "os/exec"
    "testing"
    "time"

    "github.com/stretchr/testify/require"
    "myproject/internal/testutils"
)

func TestAPI_UserWorkflow(t *testing.T) {
    // Start in-memory NATS (Level 1)
    natsServer, err := testutils.RunNATsServer()
    require.NoError(t, err)
    defer natsServer.Shutdown()

    natsAddr := "nats://" + natsServer.Addr().String()

    // Start API server
    cmd := exec.Command("./myapp", "serve",
        "--port", "0", // Random free port
        "--nats-url", natsAddr)

    // Start in background
    err = cmd.Start()
    require.NoError(t, err)
    defer cmd.Process.Kill()

    // Wait for API to be ready
    time.Sleep(500 * time.Millisecond)

    // Get actual port (from logs or endpoint)
    apiURL := "http://localhost:8080" // Or parse from logs

    // Test API workflow
    // 1. Create user
    createReq := map[string]string{
        "name":  "Alice",
        "email": "alice@example.com",
    }
    body, _ := json.Marshal(createReq)

    resp, err := http.Post(apiURL+"/users", "application/json", bytes.NewBuffer(body))
    require.NoError(t, err)
    defer resp.Body.Close()
    require.Equal(t, http.StatusCreated, resp.StatusCode)

    // Parse response
    var createResp map[string]string
    json.NewDecoder(resp.Body).Decode(&createResp)
    userID := createResp["id"]

    // 2. Retrieve user
    resp, err = http.Get(apiURL + "/users/" + userID)
    require.NoError(t, err)
    defer resp.Body.Close()
    require.Equal(t, http.StatusOK, resp.StatusCode)

    var user map[string]string
    json.NewDecoder(resp.Body).Decode(&user)
    require.Equal(t, "Alice", user["name"])
}
```

## Architecture for Independence

### Dependency Injection Pattern

Design your application to accept dependency URLs:

```go
// cmd/myapp/main.go
func main() {
    // Allow overriding dependencies via flags
    natsURL := flag.String("nats-url", "nats://localhost:4222", "NATS server URL")
    metricsURL := flag.String("metrics-url", "http://localhost:8428", "Metrics server URL")
    flag.Parse()

    // Use provided URLs (allows in-memory mocks in tests)
    app := app.New(*natsURL, *metricsURL)
    app.Run()
}
```

### Test with In-Memory Dependencies

```go
// tests/app_test.go
func TestApp_WithMocks(t *testing.T) {
    // Start all mocks
    natsServer, _ := testutils.RunNATsServer()
    defer natsServer.Shutdown()

    vmServer, _ := testutils.RunVictoriaMetricsServer()
    defer vmServer.Shutdown()

    // Test app with mocked dependencies (pure Go, no Docker!)
    cmd := exec.Command("./myapp", "serve",
        "--nats-url", "nats://"+natsServer.Addr().String(),
        "--metrics-url", vmServer.WriteURL())

    // ... test application
}
```

## Running System Tests

```bash
# Build application first
go build -o myapp ./cmd/myapp

# Run system tests
go test -v ./tests/...

# With coverage
go test -v -coverprofile=coverage.out ./tests/...

# Specific test
go test -v ./tests/... -run TestCLI_MetricsIngest
```

## Best Practices

### DO:
- Test via CLI/API only (black box)
- Use in-memory mocks from testutils
- Test critical end-to-end workflows
- Build binary before running tests
- Use temp directories for file operations

### DON'T:
- Don't import internal packages
- Don't test every edge case (that's unit/integration tests)
- Don't require Docker in CI
- Don't use sleep for timing (use polling/channels)
- Don't skip cleanup

## Key Takeaways

1. **Black box only** - Test via public interfaces
2. **Independent in Go** - No Docker required
3. **Use testutils mocks** - Reuse infrastructure
4. **Test critical paths** - Not every scenario
5. **Fast execution** - Should run quickly in CI
