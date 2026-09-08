package services

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
	"time"

	"example.com/go-mini/internal/models"
	"example.com/go-mini/internal/repository"
)

func TestNormalizeTags(t *testing.T) {
	got := normalizeTags([]string{" a ", "b", "a", "", "region:eu", "region:xx", "region:"})
	want := []string{"a", "b", "region:eu"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("normalizeTags() = %v, want %v", got, want)
	}
}

func TestParseHeartbeatLine(t *testing.T) {
	tests := []struct {
		name    string
		raw     string
		wantID  string
		wantErr bool
	}{
		{name: "ready with tags", raw: "dev-1|ready|1.2.3|a,b", wantID: "dev-1"},
		{name: "lowercase status", raw: "dev-2|degraded|1.0", wantID: "dev-2"},
		{name: "too few fields", raw: "dev-3|ready", wantErr: true},
		{name: "empty id", raw: " |ready|1.0", wantErr: true},
		{name: "unknown status", raw: "dev-4|SLEEPY|1.0", wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			id, _, _, _, err := ParseHeartbeatLine(tt.raw)
			if tt.wantErr { //nolint:nestif // TODO
				if err == nil {
					t.Fatalf("ParseHeartbeatLine(%q) expected an error", tt.raw)
				}
			} else {
				if err != nil {
					t.Fatalf("ParseHeartbeatLine(%q) unexpected error: %v", tt.raw, err)
				}
				if id != tt.wantID {
					t.Errorf("id = %q, want %q", id, tt.wantID)
				}
			}
		})
	}
}

func TestParseHeartbeatLineTags(t *testing.T) {
	_, status, version, tags, err := ParseHeartbeatLine("dev-1|ready|1.2.3|a, b ,a,region:eu,region:zz")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if status != models.StatusReady || version != "1.2.3" {
		t.Errorf("status, version = %q, %q", status, version)
	}
	if want := []string{"a", "b", "region:eu"}; !reflect.DeepEqual(tags, want) {
		t.Errorf("tags = %v, want %v", tags, want)
	}
}

func TestCacheExpiresEntries(t *testing.T) {
	c := NewCache(50 * time.Millisecond)
	c.Put(models.Device{ID: "d1", Tenant: "acme", Status: "READY"})
	if _, ok := c.Get("acme/d1"); !ok {
		t.Fatal("expected a fresh entry to be cached")
	}
	time.Sleep(100 * time.Millisecond)
	if _, ok := c.Get("acme/d1"); ok {
		t.Fatal("expected the entry to expire")
	}
	if c.Len() != 0 {
		t.Errorf("Len() = %d, want 0", c.Len())
	}
}

func TestNotifierSend(t *testing.T) {
	var got webhookPayload
	var contentType string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		contentType = r.Header.Get("Content-Type")
		body, err := io.ReadAll(r.Body)
		if err != nil {
			t.Errorf("read body: %v", err)
		}
		if err := json.Unmarshal(body, &got); err != nil {
			t.Errorf("decode body: %v", err)
		}
		w.WriteHeader(http.StatusAccepted)
	}))
	defer srv.Close()

	if err := NewNotifier(srv.URL).Send("ops", "device d1 is down"); err != nil {
		t.Fatalf("Send: %v", err)
	}
	if !strings.EqualFold(contentType, "application/json") {
		t.Errorf("Content-Type = %q", contentType)
	}
	if got.Channel != "ops" || got.Message != "device d1 is down" || got.SentAt == "" {
		t.Errorf("payload = %+v", got)
	}
}

func TestNotifierSendServerError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()
	if err := NewNotifier(srv.URL).Send("ops", "x"); err == nil {
		t.Fatal("expected an error for a 500 response")
	}
}

func TestNotifierWithoutWebhook(t *testing.T) {
	if err := NewNotifier("").Send("ops", "x"); err != nil {
		t.Fatalf("expected a no-op, got %v", err)
	}
}

func TestSendUnknownChannel(t *testing.T) {
	err := Send(models.Alert{Channel: "sms", Recipient: "+15550100", Summary: "hi"})
	if err == nil || !strings.Contains(err.Error(), "unknown channel") {
		t.Fatalf("Send() error = %v", err)
	}
}

func TestValidRecipient(t *testing.T) {
	if !validRecipient(models.Alert{Channel: "email", Recipient: "ops@example.com"}) {
		t.Error("email with @ should be valid")
	}
	if validRecipient(models.Alert{Channel: "email", Recipient: "ops"}) {
		t.Error("email without @ should be invalid")
	}
	if !validRecipient(models.Alert{Channel: "slack", Recipient: "#fleet"}) {
		t.Error("slack channel should be valid")
	}
	if validRecipient(models.Alert{Channel: "pagerduty", Recipient: "fleet-oncall"}) {
		t.Error("pagerduty is not accepted by validRecipient")
	}
}

func TestValidateAlert(t *testing.T) {
	if err := ValidateAlert(models.Alert{Channel: "slack", Recipient: "#fleet", Summary: "ok"}); err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if err := ValidateAlert(models.Alert{Channel: "slack", Recipient: "#fleet"}); err == nil {
		t.Error("expected an error for an empty summary")
	}
}

func TestRetryDelay(t *testing.T) {
	if got := retryDelay(models.Alert{Channel: "pagerduty"}); got != 500*time.Millisecond {
		t.Errorf("pagerduty delay = %v", got)
	}
	if got := retryDelay(models.Alert{Channel: "slack"}); got != 2*time.Second {
		t.Errorf("slack delay = %v", got)
	}
	if got := retryDelay(models.Alert{Channel: "email"}); got != 5*time.Second {
		t.Errorf("email delay = %v", got)
	}
}

func TestPriorityAttempts(t *testing.T) {
	if got := priorityAttempts(models.Low); got != 1 {
		t.Errorf("low = %d", got)
	}
	if got := priorityAttempts(models.Medium); got != 3 {
		t.Errorf("medium = %d", got)
	}
	if got := priorityAttempts(models.High); got != 1 {
		t.Errorf("high = %d", got)
	}
}

func TestAuditLogWrite(t *testing.T) {
	var buf bytes.Buffer
	a := NewAuditLog(&buf)
	if err := a.Write("hello"); err != nil {
		t.Fatalf("Write: %v", err)
	}
	if a.Count() != 1 {
		t.Errorf("Count() = %d", a.Count())
	}
	if !strings.Contains(buf.String(), "audit: hello") {
		t.Errorf("log = %q", buf.String())
	}
}

func TestDeviceServiceSummarize(t *testing.T) {
	s := &DeviceService{started: time.Now()}
	d := models.Device{
		ID:       "d1",
		Tenant:   "acme",
		Status:   "READY",
		Version:  "1.0",
		Tags:     []string{"a", "b"},
		LastSeen: time.Date(2024, 1, 2, 3, 4, 5, 0, time.UTC),
	}
	got := s.Summarize(d)
	for _, want := range []string{"acme/d1", "status=READY", "version=1.0", "tags=a,b", "last_seen=2024-01-02T03:04:05Z", "online"} {
		if !strings.Contains(got, want) {
			t.Errorf("Summarize() = %q, missing %q", got, want)
		}
	}
}

func TestDeviceServiceRender(t *testing.T) {
	s := &DeviceService{started: time.Now()}
	d := models.Device{ID: "d1", Tenant: "acme", Status: "DOWN"}
	if got := s.Render(d, true); got != "d1 DOWN" {
		t.Errorf("Render(short) = %q", got)
	}
	if got := s.Render(d, false); !strings.Contains(got, "status=DOWN") {
		t.Errorf("Render(long) = %q", got)
	}
}

func TestDeviceServiceScore(t *testing.T) {
	s := &DeviceService{}
	now := time.Now()
	if got := s.Score(models.Device{Status: "READY", Tags: []string{"a"}, LastSeen: now}); got != 110 {
		t.Errorf("ready score = %d", got)
	}
	if got := s.Score(models.Device{Status: "DEGRADED", LastSeen: now}); got != 50 {
		t.Errorf("degraded score = %d", got)
	}
	if got := s.Score(models.Device{Status: "DOWN", Tags: []string{"a", "b"}, LastSeen: now}); got != 0 {
		t.Errorf("down score = %d", got)
	}
}

func TestDeviceServiceGetCaches(t *testing.T) {
	ctx := context.Background()
	repo := repository.NewMemStore()
	if err := repo.Save(ctx, models.Device{ID: "d1", Tenant: "acme", Status: "READY"}); err != nil {
		t.Fatal(err)
	}
	s := &DeviceService{
		repo:     repo,
		cache:    map[string]models.Device{},
		lastSeen: map[string]time.Time{},
		started:  time.Now(),
	}
	for range 2 {
		d, err := s.Get(ctx, "acme", "d1")
		if err != nil {
			t.Fatalf("Get: %v", err)
		}
		if d.Status != models.StatusReady {
			t.Errorf("status = %q", d.Status)
		}
	}
	st := s.Stats()
	if st.Hits != 1 || st.Misses != 1 || st.Cached != 1 {
		t.Errorf("stats = %+v", st)
	}
	if _, err := s.Get(ctx, "acme", "missing"); err == nil {
		t.Error("expected an error for a missing device")
	}
}

func TestSnapshotServiceRun(t *testing.T) {
	ctx := context.Background()
	repo := repository.NewMemStore()
	for _, id := range []string{"d1", "d2", "d3"} {
		if err := repo.Save(ctx, models.Device{ID: id, Tenant: "acme", Status: "READY"}); err != nil {
			t.Fatal(err)
		}
	}
	svc := NewSnapshotService(repo, NewAuditLog(io.Discard))
	n, err := svc.Run(ctx)
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if n != 3 || len(svc.Taken()) != 3 {
		t.Errorf("taken = %d / %d", n, len(svc.Taken()))
	}
	if err := svc.Handle(ctx, models.Job{Kind: "backup"}); err == nil {
		t.Error("expected an error for an unknown job kind")
	}
}

func TestSyncServiceDryRun(t *testing.T) {
	ctx := context.Background()
	repo := repository.NewMemStore()
	if err := repo.Save(ctx, models.Device{ID: "d1", Tenant: "acme", Status: "READY", Tags: []string{"region:eu"}}); err != nil {
		t.Fatal(err)
	}
	if err := repo.Save(ctx, models.Device{ID: "d2", Tenant: "acme", Status: "READY", Tags: []string{"region:us"}}); err != nil {
		t.Fatal(err)
	}
	svc := NewSyncService(repo, NewNotifier(""), "eu", 10, 0, true)
	n, err := svc.Run(ctx)
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if n != 1 {
		t.Errorf("synced = %d, want 1", n)
	}
	if _, ok := svc.LastRun(); !ok {
		t.Error("expected LastRun to be set")
	}
	if !svc.inRegion(models.Device{Tags: []string{"region:eu"}}) {
		t.Error("expected an eu device to be in region")
	}
	if svc.inRegion(models.Device{Tags: []string{"region:us"}}) {
		t.Error("expected a us device to be out of region")
	}
}
