package handlers_test

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"example.com/go-mini/internal/handlers"
	"example.com/go-mini/internal/mocks"
	"example.com/go-mini/internal/models"
	"example.com/go-mini/internal/services"
)

type heartbeatReply struct {
	ID      string   `json:"id"`
	Score   int      `json:"score"`
	Changed bool     `json:"changed"`
	Tags    []string `json:"tags"`
	Error   string   `json:"error"`
}

// newFleetServer builds the whole service stack over a mock repository so a
// test can drive it the way a device does: one HTTP request per heartbeat.
func newFleetServer(t *testing.T) (*httptest.Server, *mocks.Repo) {
	t.Helper()
	repo := &mocks.Repo{
		Devices: map[string]models.Device{
			"acme/dev-1": {ID: "dev-1", Tenant: "acme", Status: models.StatusBooting, LastSeen: time.Now()},
		},
		Calls: map[string]int{},
	}
	svc := services.NewDeviceService(repo, services.NewNotifier(""), services.NewAuditLog(io.Discard))
	mux := http.NewServeMux()
	handlers.Routes(mux, repo, svc)
	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)
	return srv, repo
}

func postHeartbeat(t *testing.T, srv *httptest.Server, tenant, line string) (int, heartbeatReply) {
	t.Helper()
	req, err := http.NewRequest(http.MethodPost, srv.URL+"/heartbeat", strings.NewReader(line))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "text/plain")
	req.Header.Set("X-Tenant", tenant)
	resp, err := srv.Client().Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = resp.Body.Close() }()
	var reply heartbeatReply
	if err := json.NewDecoder(resp.Body).Decode(&reply); err != nil {
		t.Fatalf("decode reply: %v", err)
	}
	return resp.StatusCode, reply
}

func TestHeartbeat_RejectsOverlongID(t *testing.T) {
	srv, repo := newFleetServer(t)

	code, reply := postHeartbeat(t, srv, "acme", strings.Repeat("x", 65)+"|ready|1.0")

	if code != http.StatusBadRequest {
		t.Fatalf("status %d, want 400", code)
	}
	if reply.Error != "bad id" {
		t.Fatalf("error %q, want %q", reply.Error, "bad id")
	}
	if repo.Calls["Save"] != 0 {
		t.Fatalf("Save called %d times, want 0", repo.Calls["Save"])
	}
}

func TestHeartbeat_RejectsMissingFields(t *testing.T) {
	srv, _ := newFleetServer(t)

	code, reply := postHeartbeat(t, srv, "acme", "dev-1|ready")

	if code != http.StatusBadRequest {
		t.Fatalf("status %d, want 400", code)
	}
	if reply.Error != "bad heartbeat" {
		t.Fatalf("error %q, want %q", reply.Error, "bad heartbeat")
	}
}

func TestHeartbeat_RejectsUnknownStatus(t *testing.T) {
	srv, repo := newFleetServer(t)

	code, reply := postHeartbeat(t, srv, "acme", "dev-1|SLEEPY|1.0")

	if code != http.StatusBadRequest {
		t.Fatalf("status %d, want 400", code)
	}
	if !strings.Contains(reply.Error, "unknown status") {
		t.Fatalf("error %q, want unknown status", reply.Error)
	}
	if repo.Calls["Save"] != 0 {
		t.Fatalf("Save called %d times, want 0", repo.Calls["Save"])
	}
}

func TestHeartbeat_SavesKnownDeviceOnce(t *testing.T) {
	srv, repo := newFleetServer(t)

	code, reply := postHeartbeat(t, srv, "acme", "dev-1|ready|1.2.3|gpu, region:eu ,gpu,region:mars")

	if code != http.StatusOK {
		t.Fatalf("status %d, want 200: %+v", code, reply)
	}
	if reply.ID != "dev-1" || !reply.Changed {
		t.Fatalf("reply %+v, want dev-1 changed", reply)
	}
	if reply.Score != 120 {
		t.Fatalf("score %d, want 120 (ready + two tags)", reply.Score)
	}
	if strings.Join(reply.Tags, ",") != "gpu,region:eu" {
		t.Fatalf("tags %v, want [gpu region:eu]", reply.Tags)
	}
	if repo.Calls["Save"] != 1 {
		t.Fatalf("Save called %d times, want 1", repo.Calls["Save"])
	}
	if repo.Calls["Get"] != 1 {
		t.Fatalf("Get called %d times, want 1", repo.Calls["Get"])
	}
	if got := repo.Devices["acme/dev-1"]; got.Status != models.StatusReady || got.Version != "1.2.3" {
		t.Fatalf("stored %+v, want READY 1.2.3", got)
	}
}

func TestHeartbeat_CreatesUnknownDevice(t *testing.T) {
	srv, repo := newFleetServer(t)

	code, reply := postHeartbeat(t, srv, "acme", "dev-9|down|2.0")

	if code != http.StatusOK {
		t.Fatalf("status %d, want 200: %+v", code, reply)
	}
	if reply.Score != 0 || len(reply.Tags) != 0 {
		t.Fatalf("reply %+v, want score 0 and no tags for a device that is down", reply)
	}
	if repo.Calls["Save"] != 2 {
		t.Fatalf("Save called %d times, want 2 (create, then transition)", repo.Calls["Save"])
	}
	if _, ok := repo.Devices["acme/dev-9"]; !ok {
		t.Fatal("dev-9 was not stored")
	}
}

func TestHeartbeat_RepeatedLineKeepsStatus(t *testing.T) {
	srv, repo := newFleetServer(t)

	first, _ := postHeartbeat(t, srv, "acme", "dev-1|ready|1.0")
	if first != http.StatusOK {
		t.Fatalf("first status %d, want 200", first)
	}
	// let the first heartbeat settle before the same line arrives again
	time.Sleep(120 * time.Millisecond)
	second, reply := postHeartbeat(t, srv, "acme", "dev-1|ready|1.0")

	if second != http.StatusOK {
		t.Fatalf("second status %d, want 200", second)
	}
	if reply.Changed {
		t.Fatalf("reply %+v, want changed=false for an identical line", reply)
	}
	if repo.Calls["Save"] != 1 {
		t.Fatalf("Save called %d times, want 1 (the repeat is a no-op)", repo.Calls["Save"])
	}
	if got := repo.Devices["acme/dev-1"]; got.Status != models.StatusReady {
		t.Fatalf("stored status %q, want READY", got.Status)
	}
}
