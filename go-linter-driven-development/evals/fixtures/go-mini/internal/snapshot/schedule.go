package snapshot

import (
	"errors"
	"fmt"
	"slices"
	"time"
)

const minutesPerDay = 24 * 60

// Window is a daily time-of-day interval during which snapshots may be taken.
// A window that ends before it starts wraps past midnight.
type Window struct {
	start int // minutes since midnight
	end   int // minutes since midnight
}

// ParseWindow builds a Window from two "HH:MM" clock times.
func ParseWindow(start, end string) (Window, error) {
	s, err := parseClock(start)
	if err != nil {
		return Window{}, fmt.Errorf("window start: %w", err)
	}
	e, err := parseClock(end)
	if err != nil {
		return Window{}, fmt.Errorf("window end: %w", err)
	}
	if s == e {
		return Window{}, fmt.Errorf("window %s-%s is empty", start, end)
	}
	return Window{start: s, end: e}, nil
}

func parseClock(v string) (int, error) {
	t, err := time.Parse("15:04", v)
	if err != nil {
		return 0, fmt.Errorf("clock time %q: want HH:MM", v)
	}
	return t.Hour()*60 + t.Minute(), nil
}

// Contains reports whether t falls inside the window.
func (w Window) Contains(t time.Time) bool {
	m := t.Hour()*60 + t.Minute()
	if w.start < w.end {
		return m >= w.start && m < w.end
	}
	return m >= w.start || m < w.end
}

// Duration returns how long the window stays open each day.
func (w Window) Duration() time.Duration {
	span := w.end - w.start
	if span < 0 {
		span += minutesPerDay
	}
	return time.Duration(span) * time.Minute
}

// String renders the window as "HH:MM-HH:MM".
func (w Window) String() string {
	return fmt.Sprintf("%02d:%02d-%02d:%02d", w.start/60, w.start%60, w.end/60, w.end%60)
}

// Plan is the set of windows during which a device may be snapshotted.
type Plan struct {
	windows []Window
}

// NewPlan builds a Plan from at least one window. The plan keeps its own copy
// so later changes to the caller's slice cannot reorder or shrink it.
func NewPlan(windows []Window) (Plan, error) {
	if len(windows) == 0 {
		return Plan{}, errors.New("plan: no windows")
	}
	return Plan{windows: slices.Clone(windows)}, nil
}

// Open reports whether any window of the plan contains t.
func (p Plan) Open(t time.Time) bool {
	return slices.ContainsFunc(p.windows, func(w Window) bool { return w.Contains(t) })
}

// Windows returns the plan's windows. Callers get their own copy: the plan is
// shared by the scheduler and the status page, and neither may edit it.
func (p Plan) Windows() []Window {
	return slices.Clone(p.windows)
}
