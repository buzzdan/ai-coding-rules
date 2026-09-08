package snapshot_test

import (
	"slices"
	"testing"
	"time"

	"example.com/go-mini/internal/models"
	"example.com/go-mini/internal/snapshot"
)

func policy(retention string) map[string]string {
	return map[string]string{"retention": retention}
}

func newScheduler(t *testing.T, now time.Time) (*snapshot.Scheduler, snapshot.Repository) {
	t.Helper()
	store, err := snapshot.NewRepository(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	plan, err := snapshot.NewPlan([]snapshot.Window{mustWindow(t, "00:00", "23:59")})
	if err != nil {
		t.Fatal(err)
	}
	sched, err := snapshot.NewScheduler(store, plan, func() time.Time { return now })
	if err != nil {
		t.Fatal(err)
	}
	return sched, store
}

func put(t *testing.T, store snapshot.Repository, snaps ...models.Snapshot) {
	t.Helper()
	for _, sn := range snaps {
		if err := store.Put(sn); err != nil {
			t.Fatal(err)
		}
	}
}

func storedIDs(t *testing.T, store snapshot.Repository, deviceID string) []string {
	t.Helper()
	snaps, err := store.List(deviceID)
	if err != nil {
		t.Fatal(err)
	}
	ids := make([]string, 0, len(snaps))
	for _, sn := range snaps {
		ids = append(ids, sn.ID)
	}
	return ids
}

func TestScheduler_PruneDeletesExpiredSnapshots(t *testing.T) {
	now := time.Date(2024, time.March, 1, 12, 0, 0, 0, time.UTC)
	sched, store := newScheduler(t, now)
	old := snapshot.New("dev-1", now.Add(-40*24*time.Hour))
	fresh := snapshot.New("dev-1", now.Add(-2*24*time.Hour))
	other := snapshot.New("dev-2", now.Add(-40*24*time.Hour))
	put(t, store, old, fresh, other)

	expired, err := sched.Prune(policy("30d"), "dev-1")
	if err != nil {
		t.Fatalf("Prune: %v", err)
	}

	if len(expired) != 1 || expired[0].ID != old.ID {
		t.Fatalf("expired %v, want only %s", expired, old.ID)
	}
	if got := storedIDs(t, store, "dev-1"); !slices.Equal(got, []string{fresh.ID}) {
		t.Fatalf("dev-1 left with %v, want [%s]", got, fresh.ID)
	}
	if got := storedIDs(t, store, "dev-2"); !slices.Equal(got, []string{other.ID}) {
		t.Fatalf("dev-2 left with %v, want untouched [%s]", got, other.ID)
	}
}

func TestScheduler_PruneKeepsEverythingInsideRetention(t *testing.T) {
	now := time.Date(2024, time.March, 1, 12, 0, 0, 0, time.UTC)
	sched, store := newScheduler(t, now)
	put(t, store, snapshot.New("dev-1", now.Add(-6*24*time.Hour)))

	expired, err := sched.Prune(policy("7d"), "dev-1")
	if err != nil {
		t.Fatalf("Prune: %v", err)
	}
	if len(expired) != 0 {
		t.Fatalf("expired %v, want none", expired)
	}
}

func TestScheduler_TakeRecordsSnapshot(t *testing.T) {
	now := time.Date(2024, time.March, 1, 12, 0, 0, 0, time.UTC)
	sched, store := newScheduler(t, now)

	sn, err := sched.Take(policy("30d"), "dev-1")
	if err != nil {
		t.Fatalf("Take: %v", err)
	}

	if sn.DeviceID != "dev-1" || !sn.CreatedAt.Equal(now) {
		t.Fatalf("snapshot %+v, want dev-1 at %s", sn, now)
	}
	if got := storedIDs(t, store, "dev-1"); !slices.Equal(got, []string{sn.ID}) {
		t.Fatalf("stored %v, want [%s]", got, sn.ID)
	}
}
