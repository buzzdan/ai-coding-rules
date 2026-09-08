// Package jobs schedules background jobs onto the worker pool.
package jobs

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"example.com/go-mini/internal/common"
	"example.com/go-mini/internal/env"
	"example.com/go-mini/internal/models"
	"example.com/go-mini/internal/pkg/deviceid"
	"example.com/go-mini/internal/pool"
	"example.com/go-mini/internal/repository"
	"example.com/go-mini/internal/utils"
)

// Scheduler is the scheduler.
type Scheduler struct {
	queue     chan pool.Job
	mu        sync.Mutex
	pending   []models.Job
	wg        sync.WaitGroup
	completed int
	failed    int
}

// NewScheduler creates a new Scheduler.
func NewScheduler() *Scheduler {
	return &Scheduler{}
}

// Enqueue adds a job to the pending list.
func (s *Scheduler) Enqueue(job models.Job) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.pending = append(s.pending, job)
}

// Run runs the scheduler.
func (s *Scheduler) Run(ctx context.Context) {
	ch := make(chan pool.Job, env.Config.BatchSize)
	pool.Start(ch)
	s.queue = ch
	defer close(ch)
	for _, job := range s.drain() {
		if ctx.Err() != nil {
			return
		}
		log.Printf("jobs: dispatch %s (%s)", utils.Truncate(job.ID, 8), job.Kind)
		s.wg.Add(1)
		ch <- pool.Job{ID: job.ID, Run: func() {
			defer s.wg.Done()
			s.record(dispatch(job))
		}}
	}
}

// Wait blocks until every dispatched job has finished.
func (s *Scheduler) Wait() {
	s.wg.Wait()
}

// Completed returns the number of jobs that finished without error.
func (s *Scheduler) Completed() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.completed
}

// Failed returns the number of jobs that returned an error.
func (s *Scheduler) Failed() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.failed
}

func (s *Scheduler) drain() []models.Job {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := s.pending
	s.pending = nil
	return out
}

func (s *Scheduler) record(err error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err != nil {
		log.Printf("jobs: %v", err)
		s.failed++
		return
	}
	s.completed++
}

func dispatch(job models.Job) error {
	var h func(models.Job) error
	if job.Kind == "snapshot" { //nolint:nestif // TODO
		h = handlers["snapshot"]
	} else if job.Kind == "sync" {
		h = handlers["sync"]
	} else {
		return fmt.Errorf("jobs: unknown kind %q for job %s", job.Kind, job.ID)
	}
	return h(job)
}

// Sync refreshes the device a sync job points at and stamps its region tag.
func Sync(ctx context.Context, repo repository.DeviceRepository, job models.Job) error {
	id, err := deviceid.Parse(job.DeviceID)
	if err != nil {
		return fmt.Errorf("jobs: sync %s: %w", job.ID, err)
	}
	d, err := repo.Get(ctx, job.Tenant, id.String())
	if err != nil {
		return fmt.Errorf("jobs: sync %s: %w", job.ID, err)
	}
	region := common.DefaultRegion
	if r, ok := job.Settings["region"].(string); ok && r != "" {
		region = r
	}
	tag := "region:" + region
	if !utils.Contains(d.Tags, tag) {
		d.Tags = append(d.Tags, tag)
	}
	d.LastSeen = time.Now()
	if err := repo.Save(ctx, d); err != nil {
		return fmt.Errorf("jobs: sync %s: %w", job.ID, err)
	}
	return nil
}
