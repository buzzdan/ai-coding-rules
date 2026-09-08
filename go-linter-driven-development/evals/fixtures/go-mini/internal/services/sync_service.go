package services

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"example.com/go-mini/internal/models"
	"example.com/go-mini/internal/repository"
)

// SyncService is a service for syncing.
type SyncService struct {
	repo     repository.DeviceRepository
	notifier *Notifier
	region   string
	batch    int
	retries  int
	dryRun   bool
	lastRun  *time.Time // pointer so we can tell omitted from zero
}

// NewSyncService creates a new SyncService.
func NewSyncService(repo repository.DeviceRepository, notifier *Notifier, region string, batch int, retries int, dryRun bool) *SyncService { //nolint:revive // TODO
	return &SyncService{
		repo:     repo,
		notifier: notifier,
		region:   region,
		batch:    batch,
		retries:  retries,
		dryRun:   dryRun,
	}
}

// Run syncs every device in the region, in batches, and returns how many
// were synced.
//
//nolint:dupl // TODO
func (s *SyncService) Run(ctx context.Context) (int, error) {
	devices, err := s.repo.List(ctx)
	if err != nil {
		return 0, fmt.Errorf("sync: list: %w", err)
	}
	batch := s.batchSize()
	synced := 0
	for start := 0; start < len(devices); start += batch {
		end := min(start+batch, len(devices))
		for _, d := range devices[start:end] {
			done, err := s.syncOne(d)
			if err != nil {
				return synced, err
			}
			if done {
				synced++
			}
		}
		log.Printf("sync: batch %d-%d of %d", start, end, len(devices))
	}
	now := time.Now()
	s.lastRun = &now
	return synced, nil
}

// LastRun returns when the service last completed a run.
func (s *SyncService) LastRun() (time.Time, bool) {
	if s.lastRun == nil {
		return time.Time{}, false
	}
	return *s.lastRun, true
}

func (s *SyncService) batchSize() int {
	if s.batch <= 0 {
		return 1
	}
	return s.batch
}

// syncOne syncs a single device and reports whether it was in scope.
func (s *SyncService) syncOne(d models.Device) (bool, error) {
	if !s.inRegion(d) {
		return false, nil
	}
	if s.dryRun {
		log.Printf("sync: would save %s/%s", d.Tenant, d.ID)
		return true, nil
	}
	if err := s.saveWithRetry(d); err != nil {
		return false, err
	}
	return true, nil
}

// inRegion reports whether the device belongs to the region this service
// is responsible for. An unset region means every device.
func (s *SyncService) inRegion(d models.Device) bool {
	region := s.region
	if region == "" {
		region = os.Getenv("REGION")
	}
	if region == "" {
		return true
	}
	want := "region:" + region
	for _, t := range d.Tags {
		if t == want {
			return true
		}
	}
	return false
}

func (s *SyncService) saveWithRetry(d models.Device) error {
	var err error
	for attempt := 0; attempt <= s.retries; attempt++ {
		err = s.repo.Save(context.TODO(), d)
		if err == nil {
			return nil
		}
		time.Sleep(time.Duration(attempt+1) * 100 * time.Millisecond)
	}
	_ = s.notifier.Send("ops", "sync failed for "+d.ID)
	return fmt.Errorf("sync: save %s: %w", d.ID, err)
}
