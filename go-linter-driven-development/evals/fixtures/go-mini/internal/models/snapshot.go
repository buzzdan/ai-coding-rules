package models

import "time"

type Snapshot struct {
	ID        string
	CreatedAt time.Time
	DeviceID  string
}
