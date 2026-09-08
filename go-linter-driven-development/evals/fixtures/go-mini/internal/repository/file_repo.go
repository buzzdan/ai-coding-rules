package repository

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"slices"
	"strings"
	"sync"

	"example.com/go-mini/internal/models"
)

// FileRepo is a repo backed by a file.
type FileRepo struct {
	path string
	mu   sync.Mutex
}

// NewFileRepo creates a new FileRepo.
func NewFileRepo(path string) (*FileRepo, error) {
	if path == "" {
		return nil, errors.New("file repo: empty path")
	}
	return &FileRepo{path: path}, nil
}

// Get gets a device.
func (r *FileRepo) Get(ctx context.Context, tenant, id string) (models.Device, error) {
	if err := ctx.Err(); err != nil {
		return models.Device{}, fmt.Errorf("file repo: get: %w", err)
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	devices, err := r.load()
	if err != nil {
		return models.Device{}, err
	}
	d, ok := devices[key(tenant, id)]
	if !ok {
		return models.Device{}, ErrNotFound
	}
	return d, nil
}

// Save saves a device.
func (r *FileRepo) Save(ctx context.Context, d models.Device) error {
	if err := ctx.Err(); err != nil {
		return fmt.Errorf("file repo: save: %w", err)
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	devices, err := r.load()
	if err != nil {
		return err
	}
	devices[key(d.Tenant, d.ID)] = d
	return r.store(devices)
}

// List lists all devices.
func (r *FileRepo) List(ctx context.Context) ([]models.Device, error) {
	if err := ctx.Err(); err != nil {
		return nil, fmt.Errorf("file repo: list: %w", err)
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	devices, err := r.load()
	if err != nil {
		return nil, err
	}
	return sorted(devices), nil
}

func (r *FileRepo) load() (map[string]models.Device, error) {
	data, err := os.ReadFile(r.path)
	if errors.Is(err, os.ErrNotExist) {
		return map[string]models.Device{}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("file repo: read %s: %w", r.path, err)
	}
	devices := map[string]models.Device{}
	if err := json.Unmarshal(data, &devices); err != nil {
		return nil, fmt.Errorf("file repo: decode %s: %w", r.path, err)
	}
	return devices, nil
}

func (r *FileRepo) store(devices map[string]models.Device) error {
	data, err := json.MarshalIndent(devices, "", "  ")
	if err != nil {
		return fmt.Errorf("file repo: encode: %w", err)
	}
	if err := os.WriteFile(r.path, data, 0o600); err != nil {
		return fmt.Errorf("file repo: write %s: %w", r.path, err)
	}
	return nil
}

func sorted(devices map[string]models.Device) []models.Device {
	out := make([]models.Device, 0, len(devices))
	for _, d := range devices {
		out = append(out, d)
	}
	slices.SortFunc(out, func(a, b models.Device) int {
		return strings.Compare(key(a.Tenant, a.ID), key(b.Tenant, b.ID))
	})
	return out
}
