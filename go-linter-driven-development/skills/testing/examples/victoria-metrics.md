# Victoria Metrics Binary Test Server

## When to Use This Example

Use this when:
- Testing Prometheus Remote Write integrations
- Need real Victoria Metrics for testing metrics ingestion
- Testing PromQL queries
- Want production-like behavior without Docker
- Testing metrics pipelines end-to-end

**Dependency Level**: Level 2 (Binary) - Standalone executable via `exec.Command`

**Why Binary Instead of In-Memory:**
- Victoria Metrics is complex; reimplementing as in-memory mock isn't practical
- Need real PromQL engine behavior
- Need actual data persistence and querying
- Binary startup is fast (< 1 second) and requires no Docker

## Implementation

### Victoria Server Infrastructure

This example shows how to download, manage, and run Victoria Metrics binary for testing:

```go
// internal/testutils/victoria.go
package testutils

import (
    "context"
    "errors"
    "fmt"
    "net/http"
    "os"
    "os/exec"
    "path/filepath"
    "runtime"
    "sync"
    "time"

    "github.com/projectdiscovery/freeport"
)

const (
    DefaultVictoriaMetricsVersion = "v1.128.0"
    VictoriaMetricsVersionEnvVar  = "TEST_VICTORIA_METRICS_VERSION"
)

var (
    ErrVictoriaMetricsNotHealthy = errors.New("victoria metrics did not become healthy")
    ErrDownloadFailed            = errors.New("download failed")

    // binaryDownloadMu protects concurrent downloads (prevent race conditions)
    binaryDownloadMu sync.Mutex
)

// VictoriaServer represents a running Victoria Metrics test instance
type VictoriaServer struct {
    cmd          *exec.Cmd
    port         int
    dataPath     string
    writeURL     string
    queryURL     string
    version      string
    binaryPath   string
    shutdownOnce sync.Once
    shutdownErr  error
}

// WriteURL returns the URL for writing metrics (Prometheus Remote Write endpoint)
func (vs *VictoriaServer) WriteURL() string {
    return vs.writeURL
}

// QueryURL returns the URL for querying metrics (Prometheus-compatible query endpoint)
func (vs *VictoriaServer) QueryURL() string {
    return vs.queryURL
}

// Port returns the port Victoria Metrics is listening on
func (vs *VictoriaServer) Port() int {
    return vs.port
}

// ForceFlush forces Victoria Metrics to flush buffered samples from memory to disk,
// making them immediately queryable. This is useful for testing to avoid waiting
// for the automatic flush cycle.
func (vs *VictoriaServer) ForceFlush(ctx context.Context) error {
    url := fmt.Sprintf("http://localhost:%d/internal/force_flush", vs.port)
    req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
    if err != nil {
        return fmt.Errorf("failed to create force flush request: %w", err)
    }

    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        return fmt.Errorf("failed to force flush: %w", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        return fmt.Errorf("force flush failed: status %d", resp.StatusCode)
    }

    return nil
}

// Shutdown stops Victoria Metrics and cleans up resources.
// Safe to call multiple times (idempotent).
func (vs *VictoriaServer) Shutdown() error {
    vs.shutdownOnce.Do(func() {
        if vs.cmd == nil || vs.cmd.Process == nil {
            return
        }

        // Send interrupt signal for graceful shutdown
        if err := vs.cmd.Process.Signal(os.Interrupt); err != nil {
            vs.shutdownErr = err
            return
        }

        // Wait for process to exit (with timeout)
        done := make(chan error, 1)
        go func() {
            done <- vs.cmd.Wait()
        }()

        select {
        case <-time.After(5 * time.Second):
            vs.cmd.Process.Kill()
            vs.shutdownErr = errors.New("shutdown timeout")
        case err := <-done:
            if err != nil && err.Error() != "signal: interrupt" {
                vs.shutdownErr = err
            }
        }

        // Cleanup data directory
        if vs.dataPath != "" {
            os.RemoveAll(vs.dataPath)
        }
    })
    return vs.shutdownErr
}

// RunVictoriaMetricsServer starts a Victoria Metrics instance for testing.
// It downloads the binary if needed, starts the server, and waits for it to be healthy.
func RunVictoriaMetricsServer() (*VictoriaServer, error) {
    version := getVictoriaMetricsVersion()

    // Ensure binary exists (downloads if missing)
    binaryPath, err := ensureVictoriaBinary(version)
    if err != nil {
        return nil, err
    }

    // Get free port (prevents conflicts in parallel tests)
    freePort, err := freeport.GetFreePort("127.0.0.1", freeport.TCP)
    if err != nil {
        return nil, fmt.Errorf("failed to get free port: %w", err)
    }
    port := freePort.Port

    // Create temporary data directory
    dataPath, err := os.MkdirTemp("", "victoria-metrics-test-*")
    if err != nil {
        return nil, fmt.Errorf("failed to create temp directory: %w", err)
    }

    // Start Victoria Metrics
    cmd := exec.Command(
        binaryPath,
        fmt.Sprintf("-httpListenAddr=:%d", port),
        "-storageDataPath="+dataPath,
        "-retentionPeriod=1d",
        "-inmemoryDataFlushInterval=1ms", // Force immediate data flush for testing
    )

    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr

    if err := cmd.Start(); err != nil {
        os.RemoveAll(dataPath)
        return nil, fmt.Errorf("failed to start victoria metrics: %w", err)
    }

    baseURL := fmt.Sprintf("http://localhost:%d", port)
    server := &VictoriaServer{
        cmd:        cmd,
        port:       port,
        dataPath:   dataPath,
        writeURL:   baseURL + "/api/v1/write",
        queryURL:   baseURL + "/api/v1/query",
        version:    version,
        binaryPath: binaryPath,
    }

    // Wait for server to become healthy
    if err := waitForHealth(baseURL); err != nil {
        server.Shutdown()
        return nil, err
    }

    return server, nil
}

func getVictoriaMetricsVersion() string {
    if version := os.Getenv(VictoriaMetricsVersionEnvVar); version != "" {
        return version
    }
    return DefaultVictoriaMetricsVersion
}

// ensureVictoriaBinary ensures the Victoria Metrics binary exists, downloading if necessary.
// Thread-safe with double-check locking to prevent race conditions.
func ensureVictoriaBinary(version string) (string, error) {
    binaryName := fmt.Sprintf("victoria-metrics-%s-%s-%s", version, runtime.GOOS, getVMArch())
    binaryPath := filepath.Join(".bin", binaryName)

    // Quick check without lock (optimization)
    if _, err := os.Stat(binaryPath); err == nil {
        return binaryPath, nil
    }

    // Acquire lock to prevent concurrent downloads
    binaryDownloadMu.Lock()
    defer binaryDownloadMu.Unlock()

    // Double-check after acquiring lock (another goroutine might have downloaded it)
    if _, err := os.Stat(binaryPath); err == nil {
        return binaryPath, nil
    }

    // Create .bin directory
    if err := os.MkdirAll(".bin", 0755); err != nil {
        return "", fmt.Errorf("failed to create .bin directory: %w", err)
    }

    // Download to temporary location with unique name
    tempPath := fmt.Sprintf("%s.tmp.%d", binaryPath, os.Getpid())
    defer os.Remove(tempPath)

    downloadURL := fmt.Sprintf(
        "https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/%s/victoria-metrics-%s-%s-%s.tar.gz",
        version, runtime.GOOS, getVMArch(), version,
    )

    if err := downloadAndExtract(downloadURL, tempPath); err != nil {
        return "", fmt.Errorf("failed to download: %w", err)
    }

    if err := os.Chmod(tempPath, 0755); err != nil {
        return "", fmt.Errorf("failed to make binary executable: %w", err)
    }

    // Atomic rename - only one goroutine succeeds if multiple try
    if err := os.Rename(tempPath, binaryPath); err != nil {
        // If rename fails, check if another goroutine succeeded
        if _, statErr := os.Stat(binaryPath); statErr == nil {
            return binaryPath, nil // Another goroutine won the race
        }
        return "", fmt.Errorf("failed to rename binary: %w", err)
    }

    return binaryPath, nil
}

func getVMArch() string {
    switch runtime.GOARCH {
    case "amd64":
        return "amd64"
    case "arm64":
        return "arm64"
    default:
        return runtime.GOARCH
    }
}

func waitForHealth(baseURL string) error {
    healthURL := baseURL + "/health"
    maxRetries := 30
    retryInterval := time.Second

    ctx := context.Background()
    for range maxRetries {
        req, err := http.NewRequestWithContext(ctx, http.MethodGet, healthURL, nil)
        if err != nil {
            time.Sleep(retryInterval)
            continue
        }

        resp, err := http.DefaultClient.Do(req)
        if err == nil {
            statusOK := resp.StatusCode == http.StatusOK
            resp.Body.Close()
            if statusOK {
                return nil
            }
        }

        time.Sleep(retryInterval)
    }

    return ErrVictoriaMetricsNotHealthy
}
```

### Helper Functions for Prometheus/Victoria Metrics Testing

Add practical helpers that make tests clear and maintainable:

```go
// internal/testutils/prometheus.go
package testutils

import (
    "context"
    "encoding/json"
    "errors"
    "fmt"
    "io"
    "net/http"
    "net/url"
    "testing"
    "time"

    "github.com/gogo/protobuf/proto"
    "github.com/golang/snappy"
    "github.com/prometheus/prometheus/prompb"
    "github.com/stretchr/testify/require"
)

var (
    ErrQueryFailed     = errors.New("victoria metrics query failed")
    ErrQueryNonSuccess = errors.New("query returned non-success status")
)

// CreatePrometheusPayload creates a valid Prometheus Remote Write payload
// with a sample metric. The payload is protobuf-encoded and snappy-compressed,
// ready to be sent to Victoria Metrics' /api/v1/write endpoint.
func CreatePrometheusPayload(metricName string, value float64, labels map[string]string) ([]byte, error) {
    // Create timestamp (current time in milliseconds)
    timestampMs := time.Now().UnixMilli()

    // Build label pairs
    labelPairs := make([]prompb.Label, 0, len(labels)+1)
    labelPairs = append(labelPairs, prompb.Label{
        Name:  "__name__",
        Value: metricName,
    })
    for name, val := range labels {
        labelPairs = append(labelPairs, prompb.Label{
            Name:  name,
            Value: val,
        })
    }

    // Create a single time series with one sample
    timeseries := []prompb.TimeSeries{
        {
            Labels: labelPairs,
            Samples: []prompb.Sample{
                {
                    Value:     value,
                    Timestamp: timestampMs,
                },
            },
        },
    }

    // Create WriteRequest
    writeRequest := &prompb.WriteRequest{
        Timeseries: timeseries,
    }

    // Marshal to protobuf
    data, err := proto.Marshal(writeRequest)
    if err != nil {
        return nil, fmt.Errorf("failed to marshal protobuf: %w", err)
    }

    // Compress with snappy
    compressed := snappy.Encode(nil, data)

    return compressed, nil
}

// VMQueryResult represents a single result from a Victoria Metrics query.
type VMQueryResult struct {
    Metric map[string]string // label name -> label value
    Value  []any             // [timestamp, value_string]
}

// VMQueryResponse represents the full Victoria Metrics API response.
type VMQueryResponse struct {
    Status string `json:"status"`
    Data   struct {
        ResultType string          `json:"result_type"`
        Result     []VMQueryResult `json:"result"`
    } `json:"data"`
}

// QueryVictoriaMetrics executes a PromQL query against Victoria Metrics.
// The query is performed via the /api/v1/query endpoint with time buffer
// for clock skew and delayed indexing.
func QueryVictoriaMetrics(queryURL, query string) ([]VMQueryResult, error) {
    // Query with current time + 1 minute to catch any clock skew or delayed indexing
    currentTime := time.Now().Add(1 * time.Minute)
    fullURL := fmt.Sprintf("%s?query=%s&time=%d", queryURL, url.QueryEscape(query), currentTime.Unix())

    // Execute HTTP request
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    req, err := http.NewRequestWithContext(ctx, http.MethodGet, fullURL, nil)
    if err != nil {
        return nil, fmt.Errorf("failed to create request: %w", err)
    }

    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        return nil, fmt.Errorf("failed to execute query: %w", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        return nil, fmt.Errorf("%w: %s", ErrQueryFailed, resp.Status)
    }

    // Read response body
    bodyBytes, err := io.ReadAll(resp.Body)
    if err != nil {
        return nil, fmt.Errorf("failed to read response body: %w", err)
    }

    // Parse JSON response
    var queryResp VMQueryResponse
    if err := json.Unmarshal(bodyBytes, &queryResp); err != nil {
        return nil, fmt.Errorf("failed to decode response: %w", err)
    }

    if queryResp.Status != "success" {
        return nil, fmt.Errorf("%w: %s", ErrQueryNonSuccess, queryResp.Status)
    }

    return queryResp.Data.Result, nil
}

// AssertLabelExists checks if at least one result contains a label with the given name and value.
// Fails the test if the label is not found.
func AssertLabelExists(t *testing.T, results []VMQueryResult, labelName, labelValue string) {
    t.Helper()

    for _, result := range results {
        if val, exists := result.Metric[labelName]; exists && val == labelValue {
            return // Found it!
        }
    }

    // Label not found - fail with helpful message
    require.Fail(t, "Label not found",
        "Expected to find label %s=%s in query results, but it was not present",
        labelName, labelValue)
}
```

## Usage Examples

### Integration Test

```go
// internal/api/stats/prometheus_ingest_test.go
func TestPrometheusIngest_WithVictoriaMetrics(t *testing.T) {
    // Start real Victoria Metrics server (Level 2)
    vmServer, err := testutils.RunVictoriaMetricsServer()
    require.NoError(t, err)
    defer vmServer.Shutdown()

    // Create valid Prometheus payload using helper
    payload, err := testutils.CreatePrometheusPayload("test_metric", 42.0, map[string]string{
        "service": "api",
        "env":     "test",
    })
    require.NoError(t, err)

    // Send to Victoria Metrics
    req := httptest.NewRequest(http.MethodPost, vmServer.WriteURL(), bytes.NewBuffer(payload))
    req.Header.Set("Content-Type", "application/x-protobuf")
    req.Header.Set("Content-Encoding", "snappy")

    resp, err := http.DefaultClient.Do(req)
    require.NoError(t, err)
    defer resp.Body.Close()

    assert.Equal(t, http.StatusNoContent, resp.StatusCode)

    // Force flush to make data queryable immediately
    err = vmServer.ForceFlush(context.Background())
    require.NoError(t, err)

    // Query using helper
    results, err := testutils.QueryVictoriaMetrics(vmServer.QueryURL(), `test_metric{service="api"}`)
    require.NoError(t, err)
    require.Len(t, results, 1)

    // Assert using helper
    testutils.AssertLabelExists(t, results, "env", "test")
}
```

### System Test

```go
// tests/prometheus_ingestion_test.go
func TestE2E_PrometheusIngestion(t *testing.T) {
    // Same Victoria Metrics infrastructure!
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
    assert.Contains(t, string(output), "Metric ingested successfully")

    // Verify with helpers
    vmServer.ForceFlush(context.Background())
    results, err := testutils.QueryVictoriaMetrics(vmServer.QueryURL(), "cli_test_metric")
    require.NoError(t, err)
    require.Len(t, results, 1)
}
```

## Key Features

- **Binary download with OS/arch detection** - Works on macOS/Linux, amd64/arm64
- **Thread-safe download** - Mutex + double-check locking prevents race conditions
- **Free port allocation** - Prevents conflicts in parallel tests
- **Idempotent shutdown** - Safe to call multiple times with `sync.Once`
- **Resource cleanup** - Proper temp directory and process cleanup
- **Helper functions** - `ForceFlush()` for immediate data availability
- **Prometheus helpers** - Create payloads, query, assert on results

## Benefits

- **Production-like testing** - Testing against REAL Victoria Metrics, not mocks
- **Reusable** - Same `testutils` infrastructure for unit, integration, and system tests
- **Readable** - Helper functions make tests read like documentation
- **No Docker** - No Docker required, works in any environment
- **Fast** - Binary starts in < 1 second
- **Portable** - Works anywhere Go runs
- **Maintainable** - Changes to test infrastructure are centralized

## Key Takeaways

1. **Binary level is good for complex services** - When in-memory is too complex
2. **Download management is critical** - Thread-safe, cached, version-controlled
3. **Helper functions make tests readable** - DSL for common operations
4. **Reuse across test levels** - Same infrastructure for unit, integration, system
5. **Force flush is essential** - Make data immediately queryable in tests
