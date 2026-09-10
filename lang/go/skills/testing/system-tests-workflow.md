**Purpose**: Top rung — black box test the entire system, critical end-to-end workflows

1. **Place in tests/ folder** - At project root, separate from packages
2. **Test via CLI/API** - exec.Command for CLI, HTTP client for APIs
3. **Choose dependency level** based on what you're testing:
   - **In-memory**: Fastest, use when testing your code's behavior
   - **Binary**: exec.Command to run real executables in separate process
   - **Test-containers**: When you need real external services (DB, message queue)
4. **Test critical workflows** - User journeys, not every edge case

**Example with in-memory mock:**
```go
// tests/cli_test.go - Testing CLI against mock API
func TestCLI_UserWorkflow(t *testing.T) {
    mockAPI := testutils.NewMockServer().
        OnGET("/users/1").RespondJSON(200, user).
        Build() // In-memory httptest.Server
    defer mockAPI.Close()

    cmd := exec.Command("./myapp", "get-user", "1",
        "--api-url", mockAPI.URL())
    output, err := cmd.CombinedOutput()
    // Assert on output
}
```

**Example with binary executable:**
```go
// tests/integration_test.go - Testing against real service binary
func TestSystem_WithRealService(t *testing.T) {
    // Start service binary in background
    svc := exec.Command("./myservice", "--port", "8080")
    svc.Start()
    defer svc.Process.Kill()

    // Wait for service to be ready
    waitForHealthy(t, "http://localhost:8080/health")

    // Run tests against real service
    resp, err := http.Get("http://localhost:8080/api/users")
    // Assert on response
}
```

See reference.md for comprehensive system test patterns including test-containers.
