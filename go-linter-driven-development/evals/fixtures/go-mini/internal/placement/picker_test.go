package placement_test

import (
	"testing"

	"example.com/go-mini/internal/placement"
)

func fleet() []placement.Node {
	return []placement.Node{
		{ID: "n0", Zone: "", Capacity: 10},
		{ID: "n1", Zone: "eu", Capacity: 0},
		{ID: "n2", Zone: "eu", Capacity: 5},
		{ID: "n3", Zone: "eu", Capacity: 7},
		{ID: "n4", Zone: "us", Capacity: 3},
		{ID: "n5", Zone: "ap", Capacity: 9},
	}
}

func TestPlacer_Pick(t *testing.T) { //nolint:gocognit // TODO
	tests := []struct {
		name          string
		nodes         []placement.Node
		zone          string
		wantPrimary   string
		wantSecondary string
		wantErr       bool
	}{
		{name: "first healthy node in zone, first outside it", nodes: fleet(), zone: "eu", wantPrimary: "n2", wantSecondary: "n4"},
		{name: "zone with a single node", nodes: fleet(), zone: "us", wantPrimary: "n4", wantSecondary: "n2"},
		{name: "no node in zone", nodes: fleet(), zone: "sa", wantErr: true},
		{name: "no node outside zone", nodes: fleet()[:4], zone: "eu", wantErr: true},
		{name: "no nodes at all", nodes: nil, zone: "eu", wantErr: true},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			primary, secondary, err := placement.NewPlacer().Pick(tc.nodes, tc.zone)
			if tc.wantErr { //nolint:nestif // TODO
				if err == nil {
					t.Fatalf("expected error, got %s/%s", primary.ID, secondary.ID)
				}
			} else {
				if err != nil {
					t.Fatalf("unexpected error: %v", err)
				}
				if primary.ID != tc.wantPrimary {
					t.Errorf("primary %s, want %s", primary.ID, tc.wantPrimary)
				}
				if secondary.ID != tc.wantSecondary {
					t.Errorf("secondary %s, want %s", secondary.ID, tc.wantSecondary)
				}
			}
		})
	}
}
