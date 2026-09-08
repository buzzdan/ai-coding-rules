package utils //nolint:revive // TODO

import "time"

// DaysBetween returns the number of whole days from a to b.
func DaysBetween(a, b time.Time) int {
	if b.Before(a) {
		a, b = b, a
	}
	return int(b.Sub(a).Hours() / 24)
}
