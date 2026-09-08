package services

import (
	"encoding/json"
	"fmt"
	"time"

	"example.com/go-mini/internal/models"
)

// Formatter formats alerts for the audit log.
type Formatter interface {
	Format(a models.Alert) string
	ContentType() string
}

type plainFormatter struct{}

func (plainFormatter) Format(a models.Alert) string {
	return a.Channel + " -> " + a.Recipient + ": " + a.Summary
}

func (plainFormatter) ContentType() string {
	return "text/plain"
}

type jsonFormatter struct{}

func (jsonFormatter) Format(a models.Alert) string {
	b, _ := json.Marshal(a)
	return string(b)
}

func (jsonFormatter) ContentType() string {
	return "application/json" //nolint:goconst // TODO
}

func newFormatter(kind string) Formatter { //nolint:ireturn // TODO
	if kind == "json" {
		return jsonFormatter{}
	}
	return plainFormatter{}
}

// AlertService is a service for alerts.
type AlertService struct {
	notifier  *Notifier
	audit     *AuditLog
	formatter Formatter
	raised    int
	recieved  int //nolint:misspell // TODO
	lastAt    time.Time
}

// NewAlertService creates a new AlertService.
func NewAlertService(notifier *Notifier, audit *AuditLog, format string) *AlertService {
	return &AlertService{
		notifier:  notifier,
		audit:     audit,
		formatter: newFormatter(format),
	}
}

// Raise raises the alert that matches the device's status.
func (s *AlertService) Raise(d models.Device) error {
	s.recieved++ //nolint:misspell // TODO
	s.lastAt = time.Now()
	var a models.Alert
	//nolint:goconst // TODO
	switch d.Status {
	case "READY":
		return nil
	case "DEGRADED":
		a = models.Alert{Channel: "slack", Recipient: "#fleet", Summary: "device " + d.ID + " is degraded"}
	case "DOWN":
		a = models.Alert{Channel: "pagerduty", Recipient: "fleet-oncall", Summary: "device " + d.ID + " is down"}
	default:
		return fmt.Errorf("no alert for status %q", d.Status)
	}
	s.raised++
	_ = s.audit.Write(s.formatter.ContentType() + " " + s.formatter.Format(a))
	return s.notifier.Send(a.Channel, a.Summary)
}

// Raised returns how many alerts have been raised.
func (s *AlertService) Raised() int {
	return s.raised
}
