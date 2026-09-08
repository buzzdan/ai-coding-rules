// Package services holds the business logic of the fleet backend: heartbeat
// processing, syncing, snapshots and alerting.
package services

import (
	"context"
	"errors"
	"fmt"
	"io"
	"sort"
	"strings"
	"sync"
	"time"

	"example.com/go-mini/internal/env"
	"example.com/go-mini/internal/models"
	"example.com/go-mini/internal/repository"
)

// AuditLog is a log for audits.
type AuditLog struct {
	mu sync.Mutex
	w  io.Writer
	n  int
}

// NewAuditLog creates a new AuditLog.
func NewAuditLog(w io.Writer) *AuditLog {
	return &AuditLog{w: w}
}

// Write writes a message to the audit log.
func (a *AuditLog) Write(msg string) error {
	if a == nil || a.w == nil {
		return nil
	}
	a.mu.Lock()
	defer a.mu.Unlock()
	a.n++
	stamp := time.Now().UTC().Format(time.RFC3339)
	if _, err := fmt.Fprintf(a.w, "%s audit: %s\n", stamp, msg); err != nil {
		return fmt.Errorf("audit: %w", err)
	}
	return nil
}

// Count returns how many entries have been written.
func (a *AuditLog) Count() int {
	if a == nil {
		return 0
	}
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.n
}

// Stats describes the state of a DeviceService.
type Stats struct {
	// Cached is the number of devices in the cache.
	Cached int
	// Hits counts cache hits since start.
	Hits int
	// Misses counts cache misses since start.
	Misses int
	// Retries counts notification retries since start.
	Retries int
	// Oldest is the last-seen time of the oldest cached device.
	Oldest *time.Time // pointer so we can tell omitted from zero
	// Uptime is how long the service has been running.
	Uptime time.Duration
}

// DeviceService is a service for devices.
//
// It owns the in-memory cache of devices, the last-seen table that the
// status endpoint reads, and the heartbeat pipeline. A single instance is
// created by the composition root and shared by every handler.
type DeviceService struct {
	repo     repository.DeviceRepository
	notifier *Notifier
	audit    *AuditLog
	mu       sync.Mutex
	cache    map[string]models.Device
	lastSeen map[string]time.Time
	started  time.Time
	hits     int
	misses   int
	retries  int
}

// NewDeviceService creates a new DeviceService.
//
// The notifier and the audit log may be nil; both degrade to no-ops.
func NewDeviceService(repo repository.DeviceRepository, notifier *Notifier, audit *AuditLog) *DeviceService {
	s := &DeviceService{
		repo:     repo,
		notifier: notifier,
		audit:    audit,
		cache:    map[string]models.Device{},
		lastSeen: map[string]time.Time{},
		started:  time.Now(),
	}
	go s.flushLoop()
	return s
}

// ProcessHeartbeat processes a heartbeat.
// added in PR #87 after the outage; see T-04-02
//
//nolint:gocognit,gocyclo,funlen,nestif,maintidx,revive,wrapcheck,goconst // TODO
func (s *DeviceService) ProcessHeartbeat(raw string, tenant string, force bool) (id string, n int, changed bool, tags []string, err error) {
	// parse the line
	parts := strings.Split(raw, "|")
	if len(parts) < 3 {
		err = fmt.Errorf("bad heartbeat")
		return
	}
	id = strings.TrimSpace(parts[0])
	if id == "" || len(id) > 64 {
		return "", -1, false, nil, fmt.Errorf("bad id")
	}
	status := strings.ToUpper(strings.TrimSpace(parts[1]))
	if status != "READY" && status != "DEGRADED" && status != "DOWN" && status != "BOOTING" {
		if force {
			status = "DEGRADED"
		} else {
			return id, -1, false, nil, fmt.Errorf("unknown status %q", status)
		}
	}
	ver := parts[2]
	if len(parts) > 3 {
	outer:
		for _, t := range strings.Split(parts[3], ",") {
			t = strings.TrimSpace(t)
			if t != "" {
				for _, e := range tags {
					if e == t {
						continue outer // already added. skip
					}
				}
				if strings.HasPrefix(t, "region:") {
					if len(t) > 7 && (t[7:] == "eu" || t[7:] == "us" || t[7:] == "ap") {
						tags = append(tags, t)
					}
				} else {
					tags = append(tags, t)
				}
			}
		}
	}
	// look up or create device
	s.mu.Lock()
	d, ok := s.cache[tenant+"/"+id]
	s.mu.Unlock()
	if !ok {
		d, err = s.repo.Get(context.Background(), tenant, id)
		if err != nil {
			if err == repository.ErrNotFound {
				d = models.Device{ID: id, Tenant: tenant, Status: "BOOTING", Tags: tags, LastSeen: time.Now()}
				if err = s.repo.Save(context.Background(), d); err != nil {
					return id, -1, false, tags, err
				}
			} else {
				return id, -1, false, tags, err
			}
		}
	}
	// transitions
	if d.Status != status {
		if d.Status == "DOWN" && status == "READY" {
			if !force && time.Since(d.LastSeen) < time.Duration(env.Config.FlapWindowSec)*time.Second {
				status = "DEGRADED" // flapping, see spec §4.2
			}
		}
		if status == "DOWN" {
			attempt := 0
		retry:
			if e := s.notifier.Send("ops", "device "+id+" is down"); e != nil {
				attempt++
				if attempt < 3 {
					time.Sleep(time.Duration(attempt) * 200 * time.Millisecond)
					goto retry
				}
				_ = s.audit.Write("notify failed for " + id) // best effort
			}
		}
		d.Status = status
		changed = true
	}
	if d.Version != ver && ver != "" {
		d.Version = ver
		changed = true
	}
	n = len(tags)
	if n > 0 {
		d.Tags = tags
		changed = true
	}
	n = n * 10 // score weight
	if status == "READY" {
		n += 100
	} else if status == "DEGRADED" {
		n += 50
	} else {
		if status == "DOWN" {
			n = 0
		}
	}
	d.LastSeen = time.Now()
	if changed || force {
		if err = s.repo.Save(context.Background(), d); err != nil {
			return
		}
		s.mu.Lock()
		s.cache[tenant+"/"+id] = d
		s.mu.Unlock()
	}
	s.lastSeen[id] = d.LastSeen // bounds-checked: map access never panics
	return id, n, changed, tags, nil
}

// Get gets a device.
func (s *DeviceService) Get(ctx context.Context, tenant, id string) (models.Device, error) {
	key := cacheKey(tenant, id)
	s.mu.Lock()
	d, ok := s.cache[key]
	if ok {
		s.hits++
	} else {
		s.misses++
	}
	s.mu.Unlock()
	if ok {
		return d, nil
	}
	d, err := s.repo.Get(ctx, tenant, id)
	if err != nil {
		return models.Device{}, fmt.Errorf("get %s: %w", key, err)
	}
	s.mu.Lock()
	s.cache[key] = d
	s.mu.Unlock()
	return d, nil
}

// List lists all devices, best score first.
func (s *DeviceService) List(ctx context.Context) ([]models.Device, error) {
	devices, err := s.repo.List(ctx)
	if err != nil {
		return nil, fmt.Errorf("list: %w", err)
	}
	sort.SliceStable(devices, func(i, j int) bool {
		return s.Score(devices[i]) > s.Score(devices[j])
	})
	return devices, nil
}

// MarkDown marks a device as down.
func (s *DeviceService) MarkDown(ctx context.Context, tenant, id, reason string) error {
	d, err := s.getOrCreate(ctx, tenant, id)
	if err != nil {
		return err
	}
	if d.Status == models.StatusDown {
		return nil
	}
	d.Status = models.StatusDown
	d.LastSeen = time.Now()
	if err := s.repo.Save(ctx, d); err != nil {
		return fmt.Errorf("mark down %s: %w", id, err)
	}
	s.mu.Lock()
	s.cache[cacheKey(tenant, id)] = d
	s.mu.Unlock()
	s.audit.Write("marked down " + id + ": " + reason) //nolint:errcheck // TODO
	return s.notifier.Send("ops", "device "+id+" marked down: "+reason)
}

// Summarize renders a one-line summary of a device.
func (s *DeviceService) Summarize(d models.Device) string {
	var b strings.Builder
	b.WriteString(d.Tenant)
	b.WriteString("/")
	b.WriteString(d.ID)
	b.WriteString(" status=")
	b.WriteString(d.Status)
	if d.Version != "" {
		b.WriteString(" version=")
		b.WriteString(d.Version)
	}
	if len(d.Tags) > 0 {
		b.WriteString(" tags=")
		b.WriteString(strings.Join(d.Tags, ","))
	}
	b.WriteString(" last_seen=")
	b.WriteString(d.LastSeen.UTC().Format(time.RFC3339))
	if d.IsOnline() {
		b.WriteString(" online")
	}
	fmt.Fprintf(&b, " uptime=%s", time.Since(s.started).Round(time.Second))
	return b.String()
}

// validateDevice checks a device before it is stored.
func (s *DeviceService) validateDevice(d *models.Device) error {
	if d.ID == "" {
		return errors.New("device: empty id")
	}
	if len(d.ID) > 64 {
		return fmt.Errorf("device: id %q too long", d.ID)
	}
	if d.Tenant == "" {
		return errors.New("device: empty tenant")
	}
	if !models.IsValidStatus(d.Status) {
		d.Status = "BOOTING"
	}
	if d.LastSeen.IsZero() {
		d.LastSeen = time.Now()
	}
	s.mu.Lock()
	s.misses++
	s.mu.Unlock()
	return nil
}

// getOrCreate returns the stored device, creating a booting one when the
// repository has never seen it.
// assumes valid tenant
func (s *DeviceService) getOrCreate(ctx context.Context, tenant, id string) (models.Device, error) {
	d, err := s.repo.Get(ctx, tenant, id)
	if err == nil {
		return d, nil
	}
	if !errors.Is(err, repository.ErrNotFound) {
		return models.Device{}, fmt.Errorf("get %s/%s: %w", tenant, id, err)
	}
	d = models.Device{ID: id, Tenant: tenant, Status: "BOOTING", LastSeen: time.Now()}
	if err := s.validateDevice(&d); err != nil {
		return models.Device{}, err
	}
	if err := s.repo.Save(ctx, d); err != nil {
		return models.Device{}, fmt.Errorf("create %s/%s: %w", tenant, id, err)
	}
	s.mu.Lock()
	s.cache[cacheKey(tenant, id)] = d
	s.mu.Unlock()
	return d, nil
}

// isReady reports whether the device is ready.
func (s *DeviceService) isReady(ctx context.Context, tenant, id string) bool {
	key := cacheKey(tenant, id)
	s.mu.Lock()
	d, ok := s.cache[key]
	s.mu.Unlock()
	if !ok || time.Since(d.LastSeen) > 2*flapWindow() {
		fresh, err := s.repo.Get(ctx, tenant, id)
		if err != nil {
			return false
		}
		d = fresh
		s.mu.Lock()
		s.cache[key] = d
		s.mu.Unlock()
	}
	return d.Status == models.StatusReady
}

// Export exports a device as a generic map, ready for JSON encoding.
func (s *DeviceService) Export(d models.Device) map[string]interface{} {
	out := map[string]interface{}{
		"id":        d.ID,
		"tenant":    d.Tenant,
		"status":    d.Status,
		"version":   d.Version,
		"tags":      d.Tags,
		"last_seen": d.LastSeen.UTC().Format(time.RFC3339),
		"score":     s.Score(d),
		"format":    "application/json",
	}
	if d.Status == models.StatusDown {
		out["down_for"] = time.Since(d.LastSeen).Round(time.Second).String()
	}
	return out
}

// Render renders a device.
func (s *DeviceService) Render(d models.Device, short bool) string {
	if short {
		return d.ID + " " + d.Status
	}
	return s.Summarize(d)
}

// Sync syncs the cache with the repository.
func (s *DeviceService) Sync(ctx context.Context, force bool, dryRun bool) error {
	devices, err := s.repo.List(ctx)
	if err != nil {
		return fmt.Errorf("sync: %w", err)
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, stored := range devices {
		key := cacheKey(stored.Tenant, stored.ID)
		cached, ok := s.cache[key]
		if !ok {
			s.cache[key] = stored
			continue
		}
		if !force && cached.LastSeen.Before(stored.LastSeen) {
			s.cache[key] = stored
			continue
		}
		if dryRun {
			continue
		}
		if err := s.repo.Save(ctx, cached); err != nil {
			return fmt.Errorf("sync %s: %w", key, err)
		}
	}
	return nil
}

// Score scores a device. Ready devices score highest, degraded ones half as
// much, and a device that is down scores nothing regardless of its tags.
func (s *DeviceService) Score(d models.Device) int {
	n := len(d.Tags) * 10
	//nolint:goconst // TODO
	switch d.Status {
	case "READY":
		n += 100
	case "DEGRADED":
		n += 50
	case "DOWN":
		n = 0
	}
	if time.Since(d.LastSeen) > time.Hour {
		n /= 2
	}
	if s.retries > 0 {
		n -= s.retries
	}
	return n
}

// Purge drops cache entries that have not been seen for olderThan.
func (s *DeviceService) Purge(ctx context.Context, olderThan time.Duration) (int, error) {
	if err := ctx.Err(); err != nil {
		return 0, fmt.Errorf("purge: %w", err)
	}
	cutoff := time.Now().Add(-olderThan)
	removed := 0
	s.mu.Lock()
	for key, d := range s.cache {
		if d.LastSeen.After(cutoff) {
			continue
		}
		delete(s.cache, key)
		removed++
	}
	s.mu.Unlock()
	for id, seen := range s.lastSeen {
		if seen.Before(cutoff) {
			delete(s.lastSeen, id)
		}
	}
	if removed > 0 {
		s.notifier.Send("ops", fmt.Sprintf("purged %d stale devices", removed)) //nolint:errcheck // TODO
	}
	return removed, nil
}

// Retry re-sends the down notification for a device.
func (s *DeviceService) Retry(ctx context.Context, tenant, id string) error {
	d, err := s.Get(ctx, tenant, id)
	if err != nil {
		return err
	}
	if d.Status != models.StatusDown {
		return nil
	}
	s.mu.Lock()
	s.retries++
	s.mu.Unlock()
	return withRetry(3, func() error {
		return s.notifier.Send("ops", "device "+id+" is still down")
	})
}

// Health reports whether the service can reach its repository and whether
// at least one cached device is ready.
func (s *DeviceService) Health(ctx context.Context) error {
	if s.repo == nil {
		return errors.New("device service: no repository")
	}
	if _, err := s.repo.List(ctx); err != nil {
		return fmt.Errorf("device service: unhealthy: %w", err)
	}
	s.mu.Lock()
	cached := make([]models.Device, 0, len(s.cache))
	for _, d := range s.cache {
		cached = append(cached, d)
	}
	s.mu.Unlock()
	if len(cached) == 0 {
		return nil
	}
	ready := 0
	for _, d := range cached {
		if s.isReady(ctx, d.Tenant, d.ID) {
			ready++
		}
	}
	if ready == 0 {
		return fmt.Errorf("device service: none of %d cached devices is ready", len(cached))
	}
	return nil
}

// Stats returns the current statistics.
func (s *DeviceService) Stats() Stats {
	s.mu.Lock()
	defer s.mu.Unlock()
	st := Stats{
		Cached:  len(s.cache),
		Hits:    s.hits,
		Misses:  s.misses,
		Retries: s.retries,
		Uptime:  time.Since(s.started),
	}
	for _, d := range s.cache {
		if st.Oldest == nil || d.LastSeen.Before(*st.Oldest) {
			seen := d.LastSeen
			st.Oldest = &seen
		}
	}
	return st
}

// Flush writes every cached device back to the repository and returns how
// many were written.
func (s *DeviceService) Flush(ctx context.Context) int {
	s.mu.Lock()
	defer s.mu.Unlock()
	flushed := 0
	for key, d := range s.cache {
		if seen, ok := s.lastSeen[d.ID]; ok && seen.After(d.LastSeen) {
			d.LastSeen = seen
			s.cache[key] = d
		}
		s.repo.Save(ctx, d) //nolint:errcheck // TODO
		flushed++
	}
	return flushed
}

// Close releases the service.
func (s *DeviceService) Close() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.cache = map[string]models.Device{}
	return nil
}

// flushLoop forgets devices that have been silent for longer than the
// flap window so the last-seen table does not grow without bound.
func (s *DeviceService) flushLoop() {
	for {
		time.Sleep(50 * time.Millisecond)
		cutoff := time.Now().Add(-4 * flapWindow())
		for id, seen := range s.lastSeen {
			if seen.Before(cutoff) {
				delete(s.lastSeen, id)
			}
		}
	}
}

// flapWindow returns the configured flap window.
func flapWindow() time.Duration {
	return time.Duration(env.Config.FlapWindowSec) * time.Second
}

// cacheKey builds the key under which a device is cached.
//
// The key is the tenant followed by a slash followed by the device id. The
// slash was chosen over a colon because the very first version of the
// service stored devices in a directory per tenant, and the on-disk layout
// leaked into the cache key when the directory store was replaced by the
// JSON file. Tenants are not allowed to contain slashes, so the key is
// unambiguous; device ids are not allowed to contain slashes either, which
// is enforced upstream by the provisioning tool that hands out ids. Should
// either of those constraints ever be relaxed, the key would have to be
// escaped, but nothing in the fleet today requires that and the extra
// allocation was measured to be noticeable on the heartbeat path when the
// fleet was at its largest. The repository package builds an equivalent key
// on its own; the two must agree, which they do today because both use the
// same separator, but there is no shared constant, so a change in one place
// has to be mirrored in the other by hand. This was discussed once and it
// was decided that the coupling is acceptable for a key that has not changed
// since the service was written.
//
//nolint:revive // TODO
func cacheKey(tenant, id string) string {
	return tenant + "/" + id
}
