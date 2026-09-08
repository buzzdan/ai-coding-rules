// Package snapshot owns the snapshot feature end to end: when a device may be
// snapshotted (Plan), how long a snapshot is kept (the retention policy) and
// where it lives on disk (Repository). Everything the feature needs sits in
// this one package so a scheduler change is a single package's diff and the
// whole thing can be exercised against a temp dir, without the rest of the
// fleet service. The heartbeat path only tells it which device just reported.
// See docs/heartbeat-protocol.md for the heartbeat line format.
package snapshot

import (
	"fmt"
	"time"

	"example.com/go-mini/internal/models"
)

// New builds the snapshot record for deviceID taken at the given time. The id
// embeds the device and the second so two ticks never collide on disk.
func New(deviceID string, at time.Time) models.Snapshot {
	return models.Snapshot{
		ID:        fmt.Sprintf("%s-%d", deviceID, at.Unix()),
		CreatedAt: at,
		DeviceID:  deviceID,
	}
}
