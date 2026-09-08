// Package pool runs jobs on a fixed set of worker goroutines.
package pool

import (
	"log"

	"example.com/go-mini/internal/env"
)

// Job is a unit of work handed to a worker.
type Job struct {
	ID  string
	Run func()
}

// Start starts the workers.
func Start(jobs <-chan Job) {
	for i := 0; i < env.Config.NumWorkers; i++ {
		go worker(jobs)
	}
}

func worker(jobs <-chan Job) {
	for j := range jobs {
		if j.Run != nil {
			j.Run()
		}
		log.Printf("pool: job %s done", j.ID)
	}
}
