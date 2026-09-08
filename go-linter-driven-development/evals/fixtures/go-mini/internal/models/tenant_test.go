package models_test

import (
	"strings"
	"testing"

	"example.com/go-mini/internal/models"
)

func TestParseTenant_Success(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name string
		raw  string
	}{
		{name: "short", raw: "acme"},
		{name: "digits and dash", raw: "acme-42"},
		{name: "max length", raw: strings.Repeat("a", 32)},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			got, err := models.ParseTenant(tc.raw)
			if err != nil {
				t.Fatalf("ParseTenant(%q): unexpected error: %v", tc.raw, err)
			}
			if got.ID() != tc.raw {
				t.Errorf("ParseTenant(%q).ID() = %q, want %q", tc.raw, got.ID(), tc.raw)
			}
		})
	}
}

func TestParseTenant_Error(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name string
		raw  string
	}{
		{name: "empty", raw: ""},
		{name: "uppercase", raw: "Acme"},
		{name: "too long", raw: strings.Repeat("a", 33)},
		{name: "space", raw: "ac me"},
		{name: "underscore", raw: "ac_me"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			if _, err := models.ParseTenant(tc.raw); err == nil {
				t.Errorf("ParseTenant(%q): want error, got nil", tc.raw)
			}
		})
	}
}
