package models

import "fmt"

// ParsePriority accepts the integer devices send on the wire and rejects
// anything outside the range the scheduler knows how to order.
func ParsePriority(n int) (Priority, error) {
	if n < int(Low) || n > int(High) {
		return 0, fmt.Errorf("priority %d: want %d-%d", n, Low, High)
	}
	return Priority(n), nil
}

// Outranks reports whether p should be scheduled ahead of o.
func (p Priority) Outranks(o Priority) bool {
	return p > o
}
