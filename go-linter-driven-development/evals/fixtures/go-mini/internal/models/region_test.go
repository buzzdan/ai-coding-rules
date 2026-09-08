package models_test

import (
	"testing"

	"example.com/go-mini/internal/models"
)

func TestParseRegion_Success(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name string
		raw  string
		want models.Region
	}{
		{name: "eu", raw: "eu", want: models.RegionEU},
		{name: "us", raw: "us", want: models.RegionUS},
		{name: "ap", raw: "ap", want: models.RegionAP},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			got, err := models.ParseRegion(tc.raw)
			if err != nil {
				t.Fatalf("ParseRegion(%q): unexpected error: %v", tc.raw, err)
			}
			if got != tc.want {
				t.Errorf("ParseRegion(%q) = %q, want %q", tc.raw, got, tc.want)
			}
		})
	}
}

func TestParseRegion_Error(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name string
		raw  string
	}{
		{name: "empty", raw: ""},
		{name: "uppercase", raw: "EU"},
		{name: "unknown", raw: "mars"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			if _, err := models.ParseRegion(tc.raw); err == nil {
				t.Errorf("ParseRegion(%q): want error, got nil", tc.raw)
			}
		})
	}
}

func TestRegion_Zone(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name   string
		region models.Region
		want   string
	}{
		{name: "eu", region: models.RegionEU, want: "eu-central-1"},
		{name: "us", region: models.RegionUS, want: "us-east-1"},
		{name: "ap", region: models.RegionAP, want: "ap-southeast-1"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			if got := tc.region.Zone(); got != tc.want {
				t.Errorf("Region(%q).Zone() = %q, want %q", tc.region, got, tc.want)
			}
		})
	}
}
