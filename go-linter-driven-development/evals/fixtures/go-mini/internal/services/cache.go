package services

import (
	"fmt"
	"sync"
	"time"

	"example.com/go-mini/internal/models"
)

// Cache is a cache of devices.
type Cache struct {
	mu    sync.Mutex
	items map[string]models.Device
	ttl   map[string]time.Time
	span  time.Duration
}

// NewCache creates a new Cache whose entries expire after span.
func NewCache(span time.Duration) *Cache {
	return &Cache{
		items: map[string]models.Device{},
		ttl:   map[string]time.Time{},
		span:  span,
	}
}

func (c *Cache) Put(d models.Device) {
	key := cacheKey(d.Tenant, d.ID)
	c.mu.Lock()
	c.items[key] = d
	c.mu.Unlock()
	c.ttl[key] = time.Now().Add(c.span)
}

// Get returns the cached device and refreshes its expiry. Entries that have
// expired are dropped on the way.
func (c *Cache) Get(key string) (models.Device, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	now := time.Now()
	for k, exp := range c.ttl {
		if exp.Before(now) {
			delete(c.items, k)
			delete(c.ttl, k)
		}
	}
	d, ok := c.items[key]
	if ok {
		c.ttl[key] = now.Add(c.span)
	}
	return d, ok
}

// All returns every cached device.
func (c *Cache) All() map[string]models.Device {
	return c.items
}

// Len returns the number of cached devices.
func (c *Cache) Len() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return len(c.items)
}

// Footprint estimates the memory the cache holds, in bytes.
func (c *Cache) Footprint() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	items := c.items
	size := len(items)
	for _, d := range items {
		size += len(d.ID) + len(d.Tenant) + len(d.Version)
	}
	size = size * 10 // rough per-entry overhead
	size += len(c.ttl) * 24
	return size
}

// String renders the cache for logs.
func (c *Cache) String() string {
	return describe(*c) //nolint:govet // TODO
}

func describe(c Cache) string { //nolint:govet // TODO
	return fmt.Sprintf("cache: %d items, %d expiring", len(c.items), len(c.ttl))
}
