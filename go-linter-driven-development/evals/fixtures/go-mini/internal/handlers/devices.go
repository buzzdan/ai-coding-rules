package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"

	"example.com/go-mini/internal/models"
	"example.com/go-mini/internal/repository"
)

type registerRequest struct {
	ID     string   `json:"id"`
	Tenant string   `json:"tenant"`
	Email  string   `json:"email"`
	Tags   []string `json:"tags"`
}

// Register returns the device registration handler.
func Register(store repository.Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var body registerRequest
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			http.Error(w, "bad request body", http.StatusBadRequest)
			return
		}
		if body.ID == "" {
			http.Error(w, "id required", http.StatusBadRequest)
			return
		}
		if !strings.Contains(body.Email, "@") {
			http.Error(w, "contact email required", http.StatusBadRequest)
			return
		}
		d := models.Device{ID: body.ID, Tenant: body.Tenant, Status: "BOOTING", Tags: body.Tags}
		if err := store.Save(r.Context(), d); err != nil {
			http.Error(w, "store unavailable", http.StatusServiceUnavailable)
			return
		}
		log.Printf("registered %s/%s, contact domain %s", d.Tenant, d.ID, contactDomain(body.Email))
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(map[string]string{"id": d.ID, "status": d.Status})
	}
}

// contactDomain returns the domain of a contact address, or "" when the
// address has none.
func contactDomain(email string) string {
	if !strings.Contains(email, "@") {
		return ""
	}
	return email[strings.LastIndex(email, "@")+1:]
}
