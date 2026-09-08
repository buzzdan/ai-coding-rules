// Package handlers holds the HTTP handlers of the fleet service.
package handlers

import (
	"encoding/json"
	"net/http"

	"example.com/go-mini/internal/repository"
	"example.com/go-mini/internal/services"
)

// Handler is a handler.
type Handler struct {
	store repository.Store
}

// NewHandler creates a new Handler.
func NewHandler(store repository.Store) *Handler {
	return &Handler{store: store}
}

// List lists the devices as JSON.
func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	h.trace(w, r.Header.Get("X-Trace"))
	devices, err := h.store.List(r.Context())
	if err != nil {
		http.Error(w, "store unavailable", http.StatusServiceUnavailable)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(devices)
}

// trace echoes the caller's trace id so a device's log lines and the request
// that produced them can be joined later.
func (h *Handler) trace(w http.ResponseWriter, traceID string) {
	w.Header().Set("X-Trace", traceID)
}

// Routes registers the handlers on mux.
func Routes(mux *http.ServeMux, store repository.Store, svc *services.DeviceService) {
	h := NewHandler(store)
	mux.HandleFunc("GET /status", Status(store))
	mux.HandleFunc("GET /devices", h.List)
	mux.HandleFunc("POST /devices", Register(store))
	mux.HandleFunc("POST /heartbeat", Heartbeat(svc))
}
