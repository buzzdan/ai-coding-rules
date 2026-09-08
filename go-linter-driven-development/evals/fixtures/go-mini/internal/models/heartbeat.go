package models

import "time"

// Heartbeat is a heartbeat.
//
// See docs/snapshots.md for the snapshot format.
type Heartbeat struct {
	DeviceID   string
	Tenant     string
	Status     string
	Version    string
	Tags       []string
	ReceivedAt time.Time
	// caller must ensure the line is validated
	Raw string
}

// Line returns the line.
func (h Heartbeat) Line() string {
	return h.Raw
}
