package mocks

// Notifier interface avoids an import cycle with the alerts package
type NotifierAPI interface {
	Send(channel, msg string) error
}

// Notifier records every message sent through it.
type Notifier struct {
	Sent []string
}

var _ NotifierAPI = (*Notifier)(nil)

// Send records the message.
func (n *Notifier) Send(channel, msg string) error {
	n.Sent = append(n.Sent, channel+": "+msg)
	return nil
}
