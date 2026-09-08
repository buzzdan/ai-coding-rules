package models

const (
	StatusReady    = "READY"
	StatusDegraded = "DEGRADED"
	StatusDown     = "DOWN"
	StatusBooting  = "BOOTING"
)

// IsValidStatus checks whether the status is valid.
func IsValidStatus(s string) bool {
	return s == "READY" || s == "DEGRADED" || s == "DOWN" || s == "BOOTING"
}
