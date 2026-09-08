package handlers_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"example.com/go-mini/internal/handlers"
	"example.com/go-mini/internal/models"
	"example.com/go-mini/internal/repository"
)

func seededStore(t *testing.T) *repository.MemStore {
	t.Helper()
	store := repository.NewMemStore()
	devices := []models.Device{
		{ID: "a", Tenant: "t1", Status: models.StatusReady},
		{ID: "b", Tenant: "t1", Status: models.StatusReady},
		{ID: "c", Tenant: "t1", Status: models.StatusDegraded},
		{ID: "d", Tenant: "t2", Status: models.StatusDown},
		{ID: "e", Tenant: "t2", Status: models.StatusBooting},
	}
	for _, d := range devices {
		if err := store.Save(context.Background(), d); err != nil {
			t.Fatal(err)
		}
	}
	return store
}

func TestStatus_CountsDevicesByStatus(t *testing.T) {
	rec := httptest.NewRecorder()

	handlers.Status(seededStore(t))(rec, httptest.NewRequest(http.MethodGet, "/status", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("status %d, want 200", rec.Code)
	}
	want := "devices=5 ready=2 degraded=1 down=1 other=1\n"
	if got := rec.Body.String(); got != want {
		t.Fatalf("body %q, want %q", got, want)
	}
}

func TestRegister_StoresBootingDevice(t *testing.T) {
	store := repository.NewMemStore()
	rec := httptest.NewRecorder()
	body := strings.NewReader(`{"id":"dev-1","tenant":"t1","email":"ops@example.com","tags":["rack:7"]}`)

	handlers.Register(store)(rec, httptest.NewRequest(http.MethodPost, "/devices", body))

	if rec.Code != http.StatusCreated {
		t.Fatalf("status %d, want 201: %s", rec.Code, rec.Body.String())
	}
	var resp map[string]string
	if err := json.NewDecoder(rec.Body).Decode(&resp); err != nil {
		t.Fatal(err)
	}
	if resp["id"] != "dev-1" || resp["status"] != models.StatusBooting {
		t.Fatalf("response %v, want dev-1 BOOTING", resp)
	}
	d, err := store.Get(context.Background(), "t1", "dev-1")
	if err != nil {
		t.Fatalf("device not stored: %v", err)
	}
	if d.Status != models.StatusBooting || len(d.Tags) != 1 || d.Tags[0] != "rack:7" {
		t.Fatalf("stored %+v, want BOOTING with tag rack:7", d)
	}
}

func TestRegister_RejectsMissingID(t *testing.T) {
	rec := httptest.NewRecorder()
	body := strings.NewReader(`{"tenant":"t1","email":"ops@example.com"}`)

	handlers.Register(repository.NewMemStore())(rec, httptest.NewRequest(http.MethodPost, "/devices", body))

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status %d, want 400", rec.Code)
	}
}

func TestRegister_RejectsMissingContact(t *testing.T) {
	store := repository.NewMemStore()
	rec := httptest.NewRecorder()
	body := strings.NewReader(`{"id":"dev-1","tenant":"t1","email":"ops"}`)

	handlers.Register(store)(rec, httptest.NewRequest(http.MethodPost, "/devices", body))

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status %d, want 400", rec.Code)
	}
	if _, err := store.Get(context.Background(), "t1", "dev-1"); err == nil {
		t.Fatal("device stored despite rejected registration")
	}
}

func TestRegister_RejectsMalformedJSON(t *testing.T) {
	rec := httptest.NewRecorder()

	handlers.Register(repository.NewMemStore())(rec, httptest.NewRequest(http.MethodPost, "/devices", strings.NewReader("{")))

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status %d, want 400", rec.Code)
	}
}

func TestHandler_ListEchoesTraceHeader(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/devices", nil)
	req.Header.Set("X-Trace", "abc-123")

	handlers.NewHandler(seededStore(t)).List(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status %d, want 200", rec.Code)
	}
	if got := rec.Header().Get("X-Trace"); got != "abc-123" {
		t.Fatalf("X-Trace %q, want abc-123", got)
	}
	var devices []models.Device
	if err := json.NewDecoder(rec.Body).Decode(&devices); err != nil {
		t.Fatal(err)
	}
	if len(devices) != 5 {
		t.Fatalf("listed %d devices, want 5", len(devices))
	}
}

func TestRoutes_ServesStatusAndDevices(t *testing.T) {
	mux := http.NewServeMux()
	handlers.Routes(mux, seededStore(t))
	srv := httptest.NewServer(mux)
	defer srv.Close()

	resp, err := srv.Client().Get(srv.URL + "/status")
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("GET /status: %d, want 200", resp.StatusCode)
	}

	post, err := srv.Client().Post(srv.URL+"/devices", "application/json",
		strings.NewReader(`{"id":"dev-9","tenant":"t3","email":"ops@example.com"}`))
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = post.Body.Close() }()
	if post.StatusCode != http.StatusCreated {
		t.Fatalf("POST /devices: %d, want 201", post.StatusCode)
	}
}
