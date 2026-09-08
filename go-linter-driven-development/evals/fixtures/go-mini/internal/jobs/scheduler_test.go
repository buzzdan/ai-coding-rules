package jobs_test

import (
	"context"
	"testing"

	"example.com/go-mini/internal/env"
	"example.com/go-mini/internal/jobs"
	"example.com/go-mini/internal/mocks"
	"example.com/go-mini/internal/models"
)

func TestSync(t *testing.T) {
	repo := &mocks.Repo{Devices: map[string]models.Device{
		"t1/dev-1": {ID: "dev-1", Tenant: "t1", Status: models.StatusReady},
	}}
	job := models.Job{ID: "job-1", Kind: models.JobKindSync, DeviceID: "dev-1", Tenant: "t1"}

	if err := jobs.Sync(context.Background(), repo, job); err != nil {
		t.Fatalf("Sync: %v", err)
	}
	if repo.Calls["Save"] != 1 {
		t.Fatalf("Save called %d times, want 1", repo.Calls["Save"])
	}
	if repo.Calls["Get"] != 1 {
		t.Fatalf("Get called %d times, want 1", repo.Calls["Get"])
	}
	got := repo.Devices["t1/dev-1"].Tags
	if len(got) != 1 || got[0] != "region:eu" {
		t.Fatalf("Tags = %v, want [region:eu]", got)
	}
}

func TestSync_UnknownDevice(t *testing.T) {
	repo := &mocks.Repo{}
	job := models.Job{ID: "job-2", Kind: models.JobKindSync, DeviceID: "ghost", Tenant: "t1"}

	if err := jobs.Sync(context.Background(), repo, job); err == nil {
		t.Fatal("Sync(unknown device) = nil error, want error")
	}
	if repo.Calls["Save"] != 0 {
		t.Fatalf("Save called %d times, want 0", repo.Calls["Save"])
	}
}

func TestSchedulerRun(t *testing.T) {
	env.Load()
	ctx := context.Background()
	if err := jobs.GetStore().Save(ctx, models.Device{ID: "dev-9", Tenant: "t1", Status: models.StatusReady}); err != nil {
		t.Fatalf("seed store: %v", err)
	}

	s := jobs.NewScheduler()
	s.Enqueue(models.Job{ID: "snap-1", Kind: models.JobKindSnapshot, DeviceID: "dev-9", Tenant: "t1"})
	s.Enqueue(models.Job{ID: "sync-1", Kind: models.JobKindSync, DeviceID: "dev-9", Tenant: "t1"})
	s.Enqueue(models.Job{ID: "odd-1", Kind: "reboot", DeviceID: "dev-9", Tenant: "t1"})
	s.Run(ctx)
	s.Wait()

	if s.Completed() != 2 {
		t.Fatalf("Completed = %d, want 2", s.Completed())
	}
	if s.Failed() != 1 {
		t.Fatalf("Failed = %d, want 1", s.Failed())
	}
}

func TestSchedulerRun_Canceled(t *testing.T) {
	env.Load()
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	s := jobs.NewScheduler()
	s.Enqueue(models.Job{ID: "snap-2", Kind: models.JobKindSnapshot, DeviceID: "dev-9", Tenant: "t1"})
	s.Run(ctx)
	s.Wait()

	if s.Completed() != 0 {
		t.Fatalf("Completed = %d, want 0", s.Completed())
	}
}
