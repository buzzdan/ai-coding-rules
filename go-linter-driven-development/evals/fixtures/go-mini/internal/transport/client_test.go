package transport_test

import (
	"testing"

	"example.com/go-mini/internal/transport"
)

func TestClient_HealthURL(t *testing.T) {
	tests := []struct {
		name string
		host string
		port int
		tls  bool
		want string
	}{
		{name: "plain", host: "db", port: 5432, tls: false, want: "http://db:5432/healthz"},
		{name: "tls", host: "db", port: 5432, tls: true, want: "https://db:5432/healthz"},
		{name: "out of range port falls back to default", host: "db", port: 70000, tls: false, want: "http://db:8080/healthz"},
		{name: "zero port falls back to default", host: "db", port: 0, tls: true, want: "https://db:8080/healthz"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := transport.NewClient(tc.host, tc.port, tc.tls).HealthURL()
			if got != tc.want {
				t.Errorf("HealthURL() = %q, want %q", got, tc.want)
			}
		})
	}
}
