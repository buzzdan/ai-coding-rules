// Package deviceid identifies devices.
package deviceid

import (
	"errors"
	"fmt"
	"strings"
)

const maxLen = 64

// DeviceID is the identifier a device reports in its heartbeats.
type DeviceID string

// Parse validates raw and returns it as a DeviceID.
func Parse(raw string) (DeviceID, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "", errors.New("device id: empty")
	}
	if len(raw) > maxLen {
		return "", fmt.Errorf("device id: %d chars, want at most %d", len(raw), maxLen)
	}
	return DeviceID(raw), nil
}

// String returns the id as a string.
func (d DeviceID) String() string {
	return string(d)
}
