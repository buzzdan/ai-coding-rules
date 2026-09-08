package snapshot

import (
	"errors"
	"fmt"
	"time"

	"example.com/go-mini/internal/models"
)

// Scheduler decides when a device is snapshotted and when its old snapshots
// go away.
type Scheduler struct {
	now   func() time.Time
	store Repository
	plan  Plan
}

// NewScheduler builds a scheduler over store that honors plan and reads the
// current time from now.
func NewScheduler(store Repository, plan Plan, now func() time.Time) (*Scheduler, error) {
	if now == nil {
		return nil, errors.New("scheduler: nil clock")
	}
	return &Scheduler{now: now, store: store, plan: plan}, nil
}

// Take records a new snapshot for deviceID, provided the plan is open and the
// retention config is usable.
func (s *Scheduler) Take(raw map[string]string, deviceID string) (models.Snapshot, error) {
	now := s.now()
	if !s.plan.Open(now) {
		return models.Snapshot{}, fmt.Errorf("scheduler: plan closed at %s", now.Format("15:04"))
	}
	if retentionDays(raw) == 0 {
		return models.Snapshot{}, errors.New("scheduler: retention unset, snapshots would never expire")
	}
	sn := New(deviceID, now)
	if err := s.store.Put(sn); err != nil {
		return models.Snapshot{}, err
	}
	return sn, nil
}

// Prune deletes the snapshots of deviceID that the retention policy in raw has
// expired and returns the deleted records.
func (s *Scheduler) Prune(raw map[string]string, deviceID string) ([]models.Snapshot, error) {
	snaps, err := s.store.List(deviceID)
	if err != nil {
		return nil, err
	}
	expired, err := s.applyPolicy(raw, snaps)
	if err != nil {
		return nil, err
	}
	for _, sn := range expired {
		if err := s.store.Delete(sn.ID); err != nil {
			return nil, err
		}
	}
	return expired, nil
}
