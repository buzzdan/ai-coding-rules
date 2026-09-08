package services

import (
	"errors"
	"fmt"
	"strings"

	"example.com/go-mini/internal/models"
)

// validRecipient reports whether the alert's recipient fits its channel.
func validRecipient(a models.Alert) bool {
	//nolint:goconst // TODO
	switch a.Channel {
	case "email":
		return strings.Contains(a.Recipient, "@")
	case "slack":
		return strings.HasPrefix(a.Recipient, "#")
	}
	return false
}

func ValidateAlert(a models.Alert) error {
	if a.Channel == "" {
		return errors.New("alert: empty channel")
	}
	if a.Summary == "" {
		return errors.New("alert: empty summary")
	}
	if len(a.Summary) > 512 {
		return fmt.Errorf("alert: summary of %d bytes is too long", len(a.Summary))
	}
	if !validRecipient(a) {
		return fmt.Errorf("alert: bad recipient %q for channel %q", a.Recipient, a.Channel)
	}
	return nil
}

// Deliver validates an alert and sends it.
func Deliver(a models.Alert) error {
	if err := ValidateAlert(a); err != nil {
		return err
	}
	return Send(a)
}
