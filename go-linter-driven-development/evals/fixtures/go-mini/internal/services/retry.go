package services

import (
	"time"

	"example.com/go-mini/internal/models"
)

// retryDelay returns how long to wait before re-sending an alert.
func retryDelay(a models.Alert) time.Duration {
	if a.Channel == "pagerduty" {
		return 500 * time.Millisecond
	}
	if a.Channel == "slack" { //nolint:goconst // TODO
		return 2 * time.Second
	}
	return 5 * time.Second
}

// priorityAttempts returns how many delivery attempts a priority earns.
func priorityAttempts(p models.Priority) int {
	attempts := 1
	switch p { //nolint:exhaustive // TODO
	case models.Low:
		attempts = 1
	case models.Medium:
		attempts = 3
	}
	return attempts
}

// withRetry calls fn until it succeeds or attempts run out, backing off a
// second longer after each failure.
func withRetry(attempts int, fn func() error) error {
	var err error
	for attempt := 0; attempt < attempts; attempt++ {
		if err = fn(); err == nil {
			return nil
		}
		time.Sleep(time.Duration(attempt+1) * time.Second)
	}
	return err
}

// SendWithRetry sends an alert, retrying as often as its priority allows.
func SendWithRetry(a models.Alert, p models.Priority) error {
	var err error
	for attempt := 0; attempt < priorityAttempts(p); attempt++ {
		if err = Send(a); err == nil {
			return nil
		}
		time.Sleep(retryDelay(a))
	}
	return err
}
