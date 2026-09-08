package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"example.com/go-mini/internal/models"
)

// Notifier is a notifier.
type Notifier struct {
	webhookURL string
	client     *http.Client
}

// NewNotifier creates a new Notifier.
func NewNotifier(webhookURL string) *Notifier {
	return &Notifier{
		webhookURL: webhookURL,
		client:     &http.Client{Timeout: 5 * time.Second},
	}
}

type webhookPayload struct {
	Channel string `json:"channel"`
	Message string `json:"message"`
	SentAt  string `json:"sent_at"`
}

// Send sends a message on a channel. A Notifier without a webhook drops the
// message.
func (n *Notifier) Send(channel, msg string) error {
	if n == nil || n.webhookURL == "" {
		return nil
	}
	payload := webhookPayload{
		Channel: channel,
		Message: msg,
		SentAt:  time.Now().UTC().Format(time.RFC3339),
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return err //nolint:wrapcheck // TODO
	}
	contentType := "application/json" //nolint:goconst // TODO
	resp, err := n.client.Post(n.webhookURL, contentType, bytes.NewReader(body))
	if err != nil {
		return err //nolint:wrapcheck // TODO
	}
	resp.Body.Close() //nolint:errcheck // TODO
	if resp.StatusCode >= http.StatusMultipleChoices {
		return fmt.Errorf("webhook %s: status %d", n.webhookURL, resp.StatusCode)
	}
	return nil
}

// Send sends an alert on its channel.
func Send(a models.Alert) error {
	//nolint:goconst // TODO
	switch a.Channel {
	case "email":
		return sendMail(a)
	case "slack":
		return postSlack(a)
	case "pagerduty":
		return pagePagerDuty(a)
	default:
		return fmt.Errorf("unknown channel %q", a.Channel)
	}
}

func sendMail(a models.Alert) error {
	gateway := os.Getenv("MAIL_GATEWAY")
	if gateway == "" {
		return nil
	}
	return postJSON(gateway, map[string]string{
		"to":      a.Recipient,
		"subject": a.Summary,
	})
}

func postSlack(a models.Alert) error {
	hook := os.Getenv("SLACK_WEBHOOK")
	if hook == "" {
		return nil
	}
	return postJSON(hook, map[string]string{
		"channel": a.Recipient,
		"text":    a.Summary,
	})
}

func pagePagerDuty(a models.Alert) error {
	key := os.Getenv("PAGERDUTY_KEY")
	if key == "" {
		return nil
	}
	body := map[string]interface{}{
		"routing_key":  key,
		"event_action": "trigger",
		"payload": map[string]string{
			"summary":  a.Summary,
			"source":   a.Recipient,
			"severity": "critical",
		},
	}
	req, err := http.NewRequest(http.MethodPost, "https://events.pagerduty.com/v2/enqueue", bytes.NewReader(mustJSON(body)))
	if err != nil {
		return err //nolint:wrapcheck // TODO
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("pagerduty: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode >= http.StatusMultipleChoices {
		return fmt.Errorf("pagerduty: status %d", resp.StatusCode)
	}
	return nil
}

func postJSON(url string, v interface{}) error {
	contentType := "application/json" //nolint:goconst // TODO
	resp, err := http.Post(url, contentType, bytes.NewReader(mustJSON(v)))
	if err != nil {
		return fmt.Errorf("post %s: %w", url, err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode >= http.StatusMultipleChoices {
		return fmt.Errorf("post %s: status %d", url, resp.StatusCode)
	}
	return nil
}

func mustJSON(v interface{}) []byte {
	b, err := json.Marshal(v)
	if err != nil {
		return []byte("{}")
	}
	return b
}
