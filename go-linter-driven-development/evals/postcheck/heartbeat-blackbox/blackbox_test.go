// Package blackbox_test is the hidden top-rung oracle for every refactor case
// that touches the heartbeat path: it builds the fixture's cmd/svc binary from
// $EVAL_DIR, starts it in --dry-run mode against an httptest webhook, replays
// a fixed sequence of heartbeat lines over HTTP and compares status codes and
// bodies with a table recorded from the unmodified fixture.
//
// Black-box over the binary on purpose: it survives any internal API change,
// so an agent can rename, split or move ProcessHeartbeat freely as long as
// POST /heartbeat behaves the same. It lives outside the fixture so the agent
// under test never sees it.
//
// Re-recording (only when the fixture's contract intentionally changes):
//
//	EVAL_DIR=<scaffold> BLACKBOX_RECORD=expected.tsv go test -run Contract ./...
//
// then paste the table into `recorded` below.
package blackbox_test

import (
	_ "embed"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
)

//go:embed expected.tsv
var expectedTSV string

// step is one recorded request/response pair. tenant "-" sends no X-Tenant
// header (the service then falls back to "default").
type step struct {
	tenant   string
	force    bool
	body     string
	wantCode int
	wantBody string
}

const (
	noTenant = "-"
	// webhookFailures is how many leading webhook POSTs answer 500; the
	// service retries twice with a backoff, so the first DOWN transition
	// costs three POSTs and every later one costs one.
	webhookFailures = 2
	// wantWebhookPosts is the total number of webhook deliveries the
	// recorded sequence produces: 3 for the first DOWN transition and 1 for
	// each of the three later ones.
	wantWebhookPosts = 6
	healthDeadline   = 20 * time.Second
	healthInterval   = 50 * time.Millisecond
)

var recorded = []step{
	{"acme", false, "dev-1|READY|1.0", 200, `{"id":"dev-1","score":100,"changed":true,"tags":[]}`},
	{"acme", false, "dev-1|READY|1.0", 200, `{"id":"dev-1","score":100,"changed":false,"tags":[]}`},
	{"acme", false, "dev-1|ready|1.0", 200, `{"id":"dev-1","score":100,"changed":false,"tags":[]}`},
	{"acme", false, "dev-1|READY|1.1", 200, `{"id":"dev-1","score":100,"changed":true,"tags":[]}`},
	{"acme", false, "dev-1|DEGRADED|1.1", 200, `{"id":"dev-1","score":50,"changed":true,"tags":[]}`},
	{"acme", false, "dev-1|BOOTING|1.1", 200, `{"id":"dev-1","score":0,"changed":true,"tags":[]}`},
	{"acme", false, "dev-1|DOWN|1.1", 200, `{"id":"dev-1","score":0,"changed":true,"tags":[]}`},
	{"acme", false, "dev-1|READY|1.1", 200, `{"id":"dev-1","score":50,"changed":true,"tags":[]}`},
	{"acme", false, "dev-1|DOWN|1.1", 200, `{"id":"dev-1","score":0,"changed":true,"tags":[]}`},
	{"acme", true, "dev-1|READY|1.1", 200, `{"id":"dev-1","score":100,"changed":true,"tags":[]}`},
	{"acme", false, "dev-1|SLEEPY|1.1", 400, `{"error":"unknown status \"SLEEPY\""}`},
	{"acme", true, "dev-1|SLEEPY|1.1", 200, `{"id":"dev-1","score":50,"changed":true,"tags":[]}`},
	{"acme", false, "dev-1|sleepy|1.1", 400, `{"error":"unknown status \"SLEEPY\""}`},
	{"acme", false, "dev-1|READY", 400, `{"error":"bad heartbeat"}`},
	{"acme", false, "dev-1", 400, `{"error":"bad heartbeat"}`},
	{"acme", false, "", 400, `{"error":"bad heartbeat"}`},
	{"acme", false, "|READY|1.0", 400, `{"error":"bad id"}`},
	{"acme", false, "   |READY|1.0", 400, `{"error":"bad id"}`},
	{"acme", false, strings.Repeat("x", 65) + "|READY|1.0", 400, `{"error":"bad id"}`},
	{"acme", false, strings.Repeat("x", 64) + "|READY|1.0", 200, `{"id":"` + strings.Repeat("x", 64) + `","score":100,"changed":true,"tags":[]}`},
	{"acme", false, "dev-2|READY|2.0|gpu,ssd", 200, `{"id":"dev-2","score":120,"changed":true,"tags":["gpu","ssd"]}`},
	{"acme", false, "dev-2|READY|2.0|gpu,ssd", 200, `{"id":"dev-2","score":120,"changed":true,"tags":["gpu","ssd"]}`},
	{"acme", false, "dev-2|READY|2.0|gpu, gpu ,ssd,,  ,ssd", 200, `{"id":"dev-2","score":120,"changed":true,"tags":["gpu","ssd"]}`},
	{"acme", false, "dev-2|READY|2.0|region:eu,region:us,region:ap,region:xx,region:,region", 200, `{"id":"dev-2","score":140,"changed":true,"tags":["region:eu","region:us","region:ap","region"]}`},
	{"acme", false, "dev-2|DEGRADED|2.0|gpu,region:mars", 200, `{"id":"dev-2","score":60,"changed":true,"tags":["gpu"]}`},
	{"acme", false, "dev-2|DOWN|2.0|gpu", 200, `{"id":"dev-2","score":0,"changed":true,"tags":["gpu"]}`},
	{"acme", false, "dev-2|READY|2.0|gpu", 200, `{"id":"dev-2","score":60,"changed":true,"tags":["gpu"]}`},
	{"acme", true, "dev-2|READY|2.0|gpu", 200, `{"id":"dev-2","score":110,"changed":true,"tags":["gpu"]}`},
	{"acme", false, "dev-2|BOOTING|2.0|a,b,c", 200, `{"id":"dev-2","score":30,"changed":true,"tags":["a","b","c"]}`},
	{noTenant, false, "dev-1|READY|1.0", 200, `{"id":"dev-1","score":100,"changed":true,"tags":[]}`},
	{noTenant, false, "dev-1|READY|1.0", 200, `{"id":"dev-1","score":100,"changed":false,"tags":[]}`},
	{"beta", false, "dev-1|DOWN|3.0", 200, `{"id":"dev-1","score":0,"changed":true,"tags":[]}`},
	{"beta", false, "dev-1|DOWN|3.0", 200, `{"id":"dev-1","score":0,"changed":false,"tags":[]}`},
	{"beta", false, "dev-1|down|3.1", 200, `{"id":"dev-1","score":0,"changed":true,"tags":[]}`},
	{"beta", false, "dev-1|ready|3.1", 200, `{"id":"dev-1","score":50,"changed":true,"tags":[]}`},
	{"beta", false, "dev-1|READY|3.1", 200, `{"id":"dev-1","score":100,"changed":true,"tags":[]}`},
	{"acme", false, "dev-3|BOOTING|0.1", 200, `{"id":"dev-3","score":0,"changed":true,"tags":[]}`},
	{"acme", false, "dev-4|BOOTING|", 200, `{"id":"dev-4","score":0,"changed":false,"tags":[]}`},
	{"acme", false, "dev-4|BOOTING||x,y", 200, `{"id":"dev-4","score":20,"changed":true,"tags":["x","y"]}`},
	{"acme", true, "dev-4|READY|0.2|x", 200, `{"id":"dev-4","score":110,"changed":true,"tags":["x"]}`},
}

// webhook is the ops channel: a counter that fails its first webhookFailures
// POSTs with 500 and answers 200 afterwards, keeping every body it saw.
type webhook struct {
	mu     sync.Mutex
	bodies []string
}

func (h *webhook) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	body, _ := io.ReadAll(r.Body)
	h.mu.Lock()
	h.bodies = append(h.bodies, string(body))
	n := len(h.bodies)
	h.mu.Unlock()
	if n <= webhookFailures {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
}

func (h *webhook) received() []string {
	h.mu.Lock()
	defer h.mu.Unlock()
	return append([]string(nil), h.bodies...)
}

func TestHeartbeatContract(t *testing.T) {
	evalDir := os.Getenv("EVAL_DIR")
	if evalDir == "" {
		t.Skip("EVAL_DIR not set: point it at a scaffolded go-mini checkout")
	}
	evalDir, err := filepath.Abs(evalDir)
	if err != nil {
		t.Fatal(err)
	}

	bin := buildSvc(t, evalDir)
	hook := &webhook{}
	hookSrv := httptest.NewServer(hook)
	t.Cleanup(hookSrv.Close)
	base := startSvc(t, bin, hookSrv.URL)

	recordPath := os.Getenv("BLACKBOX_RECORD")
	var observed []step
	mismatches := 0
	for i, s := range recorded {
		code, body := postHeartbeat(t, base, s)
		observed = append(observed, step{s.tenant, s.force, s.body, code, body})
		if code != s.wantCode || body != s.wantBody {
			mismatches++
			t.Errorf("line %d %s: tenant=%s force=%v body=%q\n  got  %d %s\n  want %d %s",
				i+1, mismatchTag(recordPath), s.tenant, s.force, s.body, code, body, s.wantCode, s.wantBody)
		}
	}

	posts := hook.received()
	if len(posts) != wantWebhookPosts {
		t.Errorf("webhook received %d POSTs, want %d", len(posts), wantWebhookPosts)
	}
	for i, p := range posts {
		if !strings.Contains(p, `"channel":"ops"`) {
			t.Errorf("webhook POST %d lacks \"channel\":\"ops\": %s", i+1, p)
		}
	}

	if recordPath != "" {
		if err := os.WriteFile(recordPath, []byte(renderTSV(observed)), 0o644); err != nil {
			t.Fatal(err)
		}
		t.Logf("recorded %d lines and %d webhook POSTs to %s", len(observed), len(posts), recordPath)
	}
	if mismatches == 0 {
		t.Logf("%d heartbeat lines matched; webhook received %d POSTs", len(recorded), len(posts))
	}
}

func mismatchTag(recordPath string) string {
	if recordPath != "" {
		return "(recording — the table is being rewritten)"
	}
	return "mismatch"
}

// TestExpectedTSVMatchesTable keeps expected.tsv (the raw recording) and the
// Go table above in lock-step.
func TestExpectedTSVMatchesTable(t *testing.T) {
	fromTSV, err := parseTSV(expectedTSV)
	if err != nil {
		t.Fatal(err)
	}
	if len(fromTSV) != len(recorded) {
		t.Fatalf("expected.tsv has %d lines, the Go table has %d", len(fromTSV), len(recorded))
	}
	for i := range recorded {
		if fromTSV[i] != recorded[i] {
			t.Errorf("line %d differs:\n  tsv   %+v\n  table %+v", i+1, fromTSV[i], recorded[i])
		}
	}
}

func buildSvc(t *testing.T, evalDir string) string {
	t.Helper()
	bin := filepath.Join(t.TempDir(), "svc")
	cmd := exec.Command("go", "build", "-o", bin, "./cmd/svc")
	cmd.Dir = evalDir
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("go build ./cmd/svc in %s failed: %v\n%s", evalDir, err, out)
	}
	return bin
}

func freePort(t *testing.T) int {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	port := l.Addr().(*net.TCPAddr).Port
	if err := l.Close(); err != nil {
		t.Fatal(err)
	}
	return port
}

// startSvc launches the binary with --dry-run (in-memory store) and returns
// its base URL once /healthz answers; the process is killed at cleanup.
func startSvc(t *testing.T, bin, webhookURL string) string {
	t.Helper()
	port := freePort(t)
	cmd := exec.Command(bin, "--dry-run")
	cmd.Env = append(os.Environ(),
		"PORT="+strconv.Itoa(port),
		"WEBHOOK_URL="+webhookURL,
		"FLAP_WINDOW_SEC=30",
		"NUM_WORKERS=1",
		"BATCH=4",
		"REGION=eu",
	)
	var logs strings.Builder
	cmd.Stdout, cmd.Stderr = &logs, &logs
	if err := cmd.Start(); err != nil {
		t.Fatalf("start %s: %v", bin, err)
	}
	t.Cleanup(func() {
		_ = cmd.Process.Kill()
		_ = cmd.Wait()
		if t.Failed() {
			t.Logf("svc logs:\n%s", logs.String())
		}
	})

	base := fmt.Sprintf("http://127.0.0.1:%d", port)
	deadline := time.Now().Add(healthDeadline)
	for time.Now().Before(deadline) {
		resp, err := http.Get(base + "/healthz")
		if err == nil {
			_ = resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				return base
			}
		}
		time.Sleep(healthInterval)
	}
	t.Fatalf("svc never became healthy on %s within %s\n%s", base, healthDeadline, logs.String())
	return ""
}

func postHeartbeat(t *testing.T, base string, s step) (int, string) {
	t.Helper()
	url := base + "/heartbeat"
	if s.force {
		url += "?force=1"
	}
	req, err := http.NewRequest(http.MethodPost, url, strings.NewReader(s.body))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "text/plain")
	if s.tenant != noTenant {
		req.Header.Set("X-Tenant", s.tenant)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST %s: %v", url, err)
	}
	defer func() { _ = resp.Body.Close() }()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	return resp.StatusCode, strings.TrimSpace(string(body))
}

// TSV layout: "#\ttenant\tforce\tbody\tstatus\tresponse"; force is "1" or "".
func renderTSV(steps []step) string {
	var b strings.Builder
	b.WriteString("#\ttenant\tforce\tbody\tstatus\tresponse\n")
	for i, s := range steps {
		force := ""
		if s.force {
			force = "1"
		}
		fmt.Fprintf(&b, "%d\t%s\t%s\t%s\t%d\t%s\n", i+1, s.tenant, force, s.body, s.wantCode, s.wantBody)
	}
	return b.String()
}

func parseTSV(text string) ([]step, error) {
	var steps []step
	for n, line := range strings.Split(strings.TrimRight(text, "\n"), "\n") {
		if strings.HasPrefix(line, "#") {
			continue
		}
		f := strings.Split(line, "\t")
		if len(f) != 6 {
			return nil, fmt.Errorf("expected.tsv line %d: want 6 tab-separated fields, got %d", n+1, len(f))
		}
		code, err := strconv.Atoi(f[4])
		if err != nil {
			return nil, fmt.Errorf("expected.tsv line %d: status %q: %w", n+1, f[4], err)
		}
		steps = append(steps, step{tenant: f[1], force: f[2] == "1", body: f[3], wantCode: code, wantBody: f[5]})
	}
	return steps, nil
}
