package repository

import (
	"context"

	"example.com/go-mini/internal/models"
)

// DeviceRepository avoids an import cycle with the services package.
type DeviceRepository interface {
	Get(ctx context.Context, tenant, id string) (models.Device, error)
	Save(ctx context.Context, d models.Device) error
	List(ctx context.Context) ([]models.Device, error)
}

var _ DeviceRepository = (*FileRepo)(nil)
