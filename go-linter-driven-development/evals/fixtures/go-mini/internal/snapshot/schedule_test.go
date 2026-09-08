package snapshot_test

import (
	"testing"
	"time"

	"example.com/go-mini/internal/snapshot"
)

func at(hour, minute int) time.Time {
	return time.Date(2024, time.March, 1, hour, minute, 0, 0, time.UTC)
}

type windowCase struct {
	name     string
	start    string
	end      string
	inside   time.Time
	outside  time.Time
	duration time.Duration
	text     string
}

func checkWindow(t *testing.T, w snapshot.Window, tc windowCase) {
	t.Helper()
	if !w.Contains(tc.inside) {
		t.Errorf("%s should contain %s", w, tc.inside.Format("15:04"))
	}
	if w.Contains(tc.outside) {
		t.Errorf("%s should not contain %s", w, tc.outside.Format("15:04"))
	}
	if w.Duration() != tc.duration {
		t.Errorf("duration %s, want %s", w.Duration(), tc.duration)
	}
	if w.String() != tc.text {
		t.Errorf("String() = %q, want %q", w.String(), tc.text)
	}
}

func TestParseWindow_Success(t *testing.T) {
	tests := []windowCase{
		{
			name:     "daytime window",
			start:    "09:00",
			end:      "17:00",
			inside:   at(12, 30),
			outside:  at(17, 0),
			duration: 8 * time.Hour,
			text:     "09:00-17:00",
		},
		{
			name:     "window wrapping midnight",
			start:    "22:00",
			end:      "02:00",
			inside:   at(1, 15),
			outside:  at(12, 0),
			duration: 4 * time.Hour,
			text:     "22:00-02:00",
		},
		{
			name:     "one minute window",
			start:    "03:15",
			end:      "03:16",
			inside:   at(3, 15),
			outside:  at(3, 16),
			duration: time.Minute,
			text:     "03:15-03:16",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			w, err := snapshot.ParseWindow(tc.start, tc.end)
			if err != nil {
				t.Fatalf("ParseWindow(%q, %q): %v", tc.start, tc.end, err)
			}
			checkWindow(t, w, tc)
		})
	}
}

func TestParseWindow_Error(t *testing.T) {
	tests := []struct {
		name  string
		start string
		end   string
	}{
		{name: "empty start", start: "", end: "17:00"},
		{name: "hour out of range", start: "24:00", end: "17:00"},
		{name: "missing minutes", start: "9", end: "17:00"},
		{name: "bad end", start: "09:00", end: "5pm"},
		{name: "empty window", start: "09:00", end: "09:00"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			w, err := snapshot.ParseWindow(tc.start, tc.end)
			if err == nil {
				t.Fatalf("ParseWindow(%q, %q) = %s, want error", tc.start, tc.end, w)
			}
		})
	}
}

func mustWindow(t *testing.T, start, end string) snapshot.Window {
	t.Helper()
	w, err := snapshot.ParseWindow(start, end)
	if err != nil {
		t.Fatal(err)
	}
	return w
}

func TestNewPlan_CopiesWindows(t *testing.T) {
	night := mustWindow(t, "22:00", "02:00")
	noon := mustWindow(t, "12:00", "13:00")
	windows := []snapshot.Window{night}

	plan, err := snapshot.NewPlan(windows)
	if err != nil {
		t.Fatal(err)
	}
	windows[0] = noon

	if !plan.Open(at(23, 0)) {
		t.Error("plan lost its night window when the caller's slice changed")
	}
	if plan.Open(at(12, 30)) {
		t.Error("plan picked up a window written to the caller's slice")
	}
	if got := plan.Windows(); len(got) != 1 || got[0] != night {
		t.Errorf("Windows() = %v, want [%s]", got, night)
	}
}

func TestNewPlan_RejectsNoWindows(t *testing.T) {
	if _, err := snapshot.NewPlan(nil); err == nil {
		t.Fatal("expected error for empty plan")
	}
}
