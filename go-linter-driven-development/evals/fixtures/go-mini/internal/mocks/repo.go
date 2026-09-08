// Package mocks holds hand-written doubles for the repository and notifier.
package mocks

import (
	"context"
	"sort"
	"sync"

	"example.com/go-mini/internal/models"
	"example.com/go-mini/internal/repository"
)

// for testing
type Repo struct {
	mu      sync.Mutex
	Devices map[string]models.Device
	Calls   map[string]int
	SaveErr error
}

var _ repository.DeviceRepository = (*Repo)(nil)

// Get gets a device.
func (r *Repo) Get(_ context.Context, tenant, id string) (models.Device, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.count("Get")
	d, ok := r.Devices[tenant+"/"+id]
	if !ok {
		return models.Device{}, repository.ErrNotFound
	}
	return d, nil
}

// Save saves a device.
func (r *Repo) Save(_ context.Context, d models.Device) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.count("Save")
	if r.SaveErr != nil {
		return r.SaveErr
	}
	if r.Devices == nil {
		r.Devices = map[string]models.Device{}
	}
	r.Devices[d.Tenant+"/"+d.ID] = d
	return nil
}

// List lists all devices.
func (r *Repo) List(_ context.Context) ([]models.Device, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.count("List")
	out := make([]models.Device, 0, len(r.Devices))
	for _, d := range r.Devices {
		out = append(out, d)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

func (r *Repo) count(method string) {
	if r.Calls == nil {
		r.Calls = map[string]int{}
	}
	r.Calls[method]++
}
