package snapshot

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"example.com/go-mini/internal/models"
)

// Repository stores one JSON file per snapshot under a directory.
type Repository struct {
	dir string
}

// NewRepository opens the store under dir, creating the directory if needed.
func NewRepository(dir string) (Repository, error) {
	if dir == "" {
		return Repository{}, errors.New("snapshot repository: empty dir")
	}
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return Repository{}, fmt.Errorf("snapshot repository: mkdir %s: %w", dir, err)
	}
	return Repository{dir: dir}, nil
}

// Put writes the snapshot, replacing any earlier record with the same id.
func (r Repository) Put(sn models.Snapshot) error {
	data, err := json.Marshal(sn)
	if err != nil {
		return fmt.Errorf("snapshot repository: encode %s: %w", sn.ID, err)
	}
	if err := os.WriteFile(r.path(sn.ID), data, 0o600); err != nil {
		return fmt.Errorf("snapshot repository: write %s: %w", sn.ID, err)
	}
	return nil
}

// Delete removes the snapshot with the given id. Deleting an unknown id is
// not an error: a prune that races a manual cleanup should still succeed.
func (r Repository) Delete(id string) error {
	if err := os.Remove(r.path(id)); err != nil && !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("snapshot repository: delete %s: %w", id, err)
	}
	return nil
}

// List returns the snapshots of deviceID, oldest first.
func (r Repository) List(deviceID string) ([]models.Snapshot, error) {
	entries, err := os.ReadDir(r.dir)
	if err != nil {
		return nil, fmt.Errorf("snapshot repository: read %s: %w", r.dir, err)
	}
	var out []models.Snapshot
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}
		sn, err := r.read(entry.Name())
		if err != nil {
			return nil, err
		}
		if sn.DeviceID == deviceID {
			out = append(out, sn)
		}
	}
	slices.SortFunc(out, func(a, b models.Snapshot) int { return a.CreatedAt.Compare(b.CreatedAt) })
	return out, nil
}

func (r Repository) read(name string) (models.Snapshot, error) {
	data, err := os.ReadFile(filepath.Join(r.dir, name))
	if err != nil {
		return models.Snapshot{}, fmt.Errorf("snapshot repository: read %s: %w", name, err)
	}
	var sn models.Snapshot
	if err := json.Unmarshal(data, &sn); err != nil {
		return models.Snapshot{}, fmt.Errorf("snapshot repository: decode %s: %w", name, err)
	}
	return sn, nil
}

func (r Repository) path(id string) string {
	return filepath.Join(r.dir, url.PathEscape(id)+".json")
}
