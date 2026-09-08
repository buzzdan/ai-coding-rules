// Package repository persists devices.
package repository

import (
	"context"
	"errors"

	"example.com/go-mini/internal/models"
)

// ErrNotFound is returned when no device matches the tenant and id.
var ErrNotFound = errors.New("device not found")

// Store is the persistence boundary for devices. Two production stores
// implement it: FileRepo keeps the fleet in a JSON file, and MemStore backs
// `svc --dry-run` so an operator can replay heartbeats without touching disk.
type Store interface {
	Get(ctx context.Context, tenant, id string) (models.Device, error)
	Save(ctx context.Context, d models.Device) error
	List(ctx context.Context) ([]models.Device, error)
}

var (
	_ Store = (*FileRepo)(nil)
	_ Store = (*MemStore)(nil)
)

func key(tenant, id string) string {
	return tenant + "/" + id
}
