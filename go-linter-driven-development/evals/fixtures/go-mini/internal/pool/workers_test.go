package pool_test

import (
	"testing"

	"example.com/go-mini/internal/env"
	"example.com/go-mini/internal/pool"
)

func TestStart(t *testing.T) {
	env.Config.NumWorkers = 2

	ids := []string{"job-a", "job-b"}
	done := make(chan string, len(ids))
	jobs := make(chan pool.Job)
	pool.Start(jobs)

	for _, id := range ids {
		jobs <- pool.Job{ID: id, Run: func() { done <- id }}
	}
	close(jobs)

	seen := map[string]bool{}
	for range ids {
		seen[<-done] = true
	}
	for _, id := range ids {
		if !seen[id] {
			t.Fatalf("job %s never ran", id)
		}
	}
}
