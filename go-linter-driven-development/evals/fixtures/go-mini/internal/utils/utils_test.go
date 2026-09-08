package utils_test

import (
	"testing"
	"time"

	"example.com/go-mini/internal/utils"
)

func TestTruncate(t *testing.T) {
	if got := utils.Truncate("heartbeat", 5); got != "heart" {
		t.Fatalf("Truncate = %q, want %q", got, "heart")
	}
	if got := utils.Truncate("hb", 5); got != "hb" {
		t.Fatalf("Truncate short = %q, want %q", got, "hb")
	}
}

func TestSlugify(t *testing.T) {
	if got := utils.Slugify("Device  #12 / EU"); got != "device-12-eu" {
		t.Fatalf("Slugify = %q, want %q", got, "device-12-eu")
	}
}

func TestContains(t *testing.T) {
	tags := []string{"gpu", "region:eu"}
	if !utils.Contains(tags, "gpu") {
		t.Fatal("Contains(gpu) = false, want true")
	}
	if utils.Contains(tags, "cpu") {
		t.Fatal("Contains(cpu) = true, want false")
	}
}

func TestDaysBetween(t *testing.T) {
	a := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
	b := a.Add(72 * time.Hour)
	if got := utils.DaysBetween(a, b); got != 3 {
		t.Fatalf("DaysBetween = %d, want 3", got)
	}
	if got := utils.DaysBetween(b, a); got != 3 {
		t.Fatalf("DaysBetween reversed = %d, want 3", got)
	}
}
