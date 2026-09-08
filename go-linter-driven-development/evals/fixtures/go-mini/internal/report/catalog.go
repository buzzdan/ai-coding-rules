package report

import "slices"

// Device is a device known to the catalog.
type Device struct {
	Name  string
	Model string
}

// Event returns the catalog event for the device.
func (d Device) Event() Event {
	return Event{Kind: "catalog", Subject: d.Name + "/" + d.Model}
}

// Catalog is a catalog of devices.
type Catalog struct {
	devices []Device
}

// NewCatalog creates a new Catalog holding its own copy of devices.
func NewCatalog(devices []Device) *Catalog {
	return &Catalog{devices: slices.Clone(devices)}
}

// Find finds the device by name.
func (c *Catalog) Find(name string) *Device {
	for i := range c.devices {
		if c.devices[i].Name == name {
			return &c.devices[i]
		}
	}
	return nil
}
