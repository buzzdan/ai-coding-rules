// Package models holds the domain types shared by every layer of the service.
package models

import "time"

// Device is a device.
type Device struct {
	ID       string
	Tenant   string
	Status   string
	Version  string
	Tags     []string
	LastSeen time.Time
}

// SetStatus sets the status.
func (d *Device) SetStatus(s string) {
	d.Status = s
}

// IsOnline returns whether the device is online.
func (d Device) IsOnline() bool {
	return d.Status == "READY" || d.Status == "DEGRADED"
}
