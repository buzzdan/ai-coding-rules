package repository

import (
	"context"
	"fmt"
	"sync"

	"example.com/go-mini/internal/models"
)

// MemStore keeps the fleet in memory. It is the store behind `svc --dry-run`,
// where an operator replays recorded heartbeats without writing anything to
// disk.
type MemStore struct {
	mu      sync.Mutex
	devices map[string]models.Device
}

// NewMemStore creates a new MemStore.
func NewMemStore() *MemStore {
	return &MemStore{devices: map[string]models.Device{}}
}

// Get gets a device.
func (m *MemStore) Get(ctx context.Context, tenant, id string) (models.Device, error) {
	if err := ctx.Err(); err != nil {
		return models.Device{}, fmt.Errorf("mem store: get: %w", err)
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	d, ok := m.devices[key(tenant, id)]
	if !ok {
		return models.Device{}, ErrNotFound
	}
	return d, nil
}

// Save saves a device.
func (m *MemStore) Save(ctx context.Context, d models.Device) error {
	if err := ctx.Err(); err != nil {
		return fmt.Errorf("mem store: save: %w", err)
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	m.devices[key(d.Tenant, d.ID)] = d
	return nil
}

// List lists all devices.
func (m *MemStore) List(ctx context.Context) ([]models.Device, error) {
	if err := ctx.Err(); err != nil {
		return nil, fmt.Errorf("mem store: list: %w", err)
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	return sorted(m.devices), nil
}
