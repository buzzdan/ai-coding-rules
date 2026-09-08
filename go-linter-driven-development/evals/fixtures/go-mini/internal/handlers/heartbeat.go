package handlers

import (
	"encoding/json"
	"io"
	"net/http"

	"example.com/go-mini/internal/services"
)

// maxHeartbeatBytes bounds a heartbeat line; the longest legitimate line is
// well under a kilobyte.
const maxHeartbeatBytes = 4096

type heartbeatResponse struct {
	ID      string   `json:"id"`
	Score   int      `json:"score"`
	Changed bool     `json:"changed"`
	Tags    []string `json:"tags"`
}

// Heartbeat returns the heartbeat handler. The body is one raw heartbeat
// line, the tenant comes from the X-Tenant header and ?force=1 forces the
// reported status through.
func Heartbeat(svc *services.DeviceService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		raw, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxHeartbeatBytes))
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "unreadable body"})
			return
		}
		tenant := r.Header.Get("X-Tenant")
		if tenant == "" {
			tenant = "default"
		}
		force := r.URL.Query().Get("force") == "1"

		id, score, changed, tags, err := svc.ProcessHeartbeat(string(raw), tenant, force)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
			return
		}
		if tags == nil {
			tags = []string{}
		}
		writeJSON(w, http.StatusOK, heartbeatResponse{ID: id, Score: score, Changed: changed, Tags: tags})
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
