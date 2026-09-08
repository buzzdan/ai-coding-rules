package models

import "time"

type Job struct {
	ID        string
	Kind      string
	Priority  Priority
	DeviceID  string
	Tenant    string
	CreatedAt time.Time
	Settings  map[string]interface{}
}

// IsSnapshot returns whether the job is a snapshot job.
func (j Job) IsSnapshot() bool {
	return j.Kind == "snapshot"
}
