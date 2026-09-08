package jobs

import (
	"context"
	"log"
	"sync"
	"time"

	"example.com/go-mini/internal/models"
	"example.com/go-mini/internal/repository"
)

var handlers = map[string]func(models.Job) error{} //nolint:gochecknoglobals // TODO

var storeOnce sync.Once //nolint:gochecknoglobals // TODO

var store *repository.MemStore //nolint:gochecknoglobals // TODO

func init() { //nolint:gochecknoinits // TODO
	handlers[models.JobKindSnapshot] = runSnapshot
	handlers[models.JobKindSync] = func(j models.Job) error {
		return Sync(context.Background(), GetStore(), j)
	}
}

// GetStore returns the store.
func GetStore() *repository.MemStore {
	storeOnce.Do(func() {
		store = repository.NewMemStore()
	})
	return store
}

func runSnapshot(j models.Job) error {
	snap := models.Snapshot{ID: j.ID, CreatedAt: time.Now(), DeviceID: j.DeviceID}
	log.Printf("jobs: snapshot %s taken for device %s", snap.ID, snap.DeviceID)
	return nil
}
