package services

import (
	"context"
	"errors"
	"fmt"
	"log"
	"sync"
	"time"

	"example.com/go-mini/internal/env"
	"example.com/go-mini/internal/models"
	"example.com/go-mini/internal/repository"
)

// SnapshotService is a service for snapshots.
type SnapshotService struct {
	repo    repository.DeviceRepository
	audit   *AuditLog
	mu      sync.Mutex
	taken   []models.Snapshot
	lastRun *time.Time // pointer so we can tell omitted from zero
}

// NewSnapshotService creates a new SnapshotService.
func NewSnapshotService(repo repository.DeviceRepository, audit *AuditLog) *SnapshotService {
	return &SnapshotService{repo: repo, audit: audit}
}

// Run snapshots every device, in batches, and returns how many were taken.
//
//nolint:dupl // TODO
func (s *SnapshotService) Run(ctx context.Context) (int, error) {
	devices, err := s.repo.List(ctx)
	if err != nil {
		return 0, fmt.Errorf("snapshot: list: %w", err)
	}
	batch := s.batchSize()
	taken := 0
	for start := 0; start < len(devices); start += batch {
		end := min(start+batch, len(devices))
		for _, d := range devices[start:end] {
			done, err := s.take(d)
			if err != nil {
				return taken, err
			}
			if done {
				taken++
			}
		}
		log.Printf("snapshot: batch %d-%d of %d", start, end, len(devices))
	}
	now := time.Now()
	s.lastRun = &now
	return taken, nil
}

func (s *SnapshotService) batchSize() int {
	if env.Config.BatchSize <= 0 {
		return 1
	}
	return env.Config.BatchSize
}

// take snapshots a single device and reports whether a snapshot was taken.
// Devices that are down are skipped: there is nothing worth keeping.
func (s *SnapshotService) take(d models.Device) (bool, error) {
	if d.ID == "" {
		return false, errors.New("snapshot: device without id")
	}
	if d.Status == models.StatusDown {
		return false, nil
	}
	now := time.Now()
	snap := models.Snapshot{
		ID:        fmt.Sprintf("%s/%s@%d", d.Tenant, d.ID, now.UnixNano()),
		CreatedAt: now,
		DeviceID:  d.ID,
	}
	s.mu.Lock()
	s.taken = append(s.taken, snap)
	s.mu.Unlock()
	_ = s.audit.Write("snapshot " + snap.ID)
	return true, nil
}

// Taken returns the snapshots taken so far.
func (s *SnapshotService) Taken() []models.Snapshot {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.taken
}

// Handle runs the job if it is a snapshot job.
func (s *SnapshotService) Handle(ctx context.Context, job models.Job) error {
	if job.Kind == "snapshot" {
		_, err := s.Run(ctx)
		return err
	}
	if job.Kind == "sync" {
		return nil // sync jobs are handled by the sync service
	}
	return fmt.Errorf("snapshot: unknown job kind %q", job.Kind)
}

// Manifest describes the snapshots taken so far.
func (s *SnapshotService) Manifest() map[string]interface{} {
	s.mu.Lock()
	defer s.mu.Unlock()
	contentType := "application/json" //nolint:goconst // TODO
	return map[string]interface{}{
		"count":        len(s.taken),
		"content_type": contentType,
		"snapshots":    s.taken,
	}
}
