package handlers

import (
	"fmt"
	"net/http"

	"example.com/go-mini/internal/repository"
)

// Status returns the status handler.
func Status(store repository.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		devices, err := store.List(r.Context())
		if err != nil {
			http.Error(w, "store unavailable", http.StatusServiceUnavailable)
			return
		}
		var ready, degraded, down, other int
		for _, d := range devices {
			switch d.Status {
			case "READY":
				ready++
			case "DEGRADED":
				degraded++
			case "DOWN":
				down++
			default:
				other++
			}
		}
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = fmt.Fprintf(w, "devices=%d ready=%d degraded=%d down=%d other=%d\n",
			len(devices), ready, degraded, down, other)
	}
}
