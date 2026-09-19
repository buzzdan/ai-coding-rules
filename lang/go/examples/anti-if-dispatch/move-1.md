Define the interface from the union of what the copies do: `Send` switches on
delivery, `validRecipient` on addressing, `retryDelay` on retry policy — three
methods, one type per variant:

```go
// alert/channel.go
type Channel interface {
    Send(a Alert) error
    ValidRecipient(recipient string) bool
    RetryDelay() time.Duration
}

// ParseChannel is the single decision point. This switch is ALLOWED —
// it is the one place the raw string may be inspected (R11), exactly as
// a ParseX constructor is the one place a raw value is validated (R2).
func ParseChannel(name string) (Channel, error) {
    switch name {
    case "email":
        return Email{}, nil
    case "slack":
        return Slack{}, nil
    case "pagerduty":
        return PagerDuty{}, nil
    default:
        return nil, fmt.Errorf("unknown channel %q", name)
    }
}
```

```go
// alert/slack.go — each variant is a leaf type owning ALL its behavior
type Slack struct{}

func (Slack) Send(a Alert) error           { return slackPost(a.Recipient, renderSlack(a)) }
func (Slack) ValidRecipient(r string) bool { return strings.HasPrefix(r, "#") }
func (Slack) RetryDelay() time.Duration    { return 5 * time.Second }
```

`Alert` now holds a `Channel`, constructed at the boundary (the HTTP handler or
config loader calls `ParseChannel` and fails fast there). The three switching sites
collapse to method calls:

```go
func Send(a Alert) error            { return a.Channel.Send(a) }
func validRecipient(a Alert) bool   { return a.Channel.ValidRecipient(a.Recipient) }
func retryDelay(a Alert) time.Duration { return a.Channel.RetryDelay() }
```

(And once they are one-liners, the wrappers themselves usually dissolve into their
callers — the story functions call the methods directly, R3.)

What was deleted, not relocated: every `default:` arm downstream. An `Alert` that
exists holds a `Channel` that exists; "unknown channel" is unrepresentable past
`ParseChannel`. Adding SMS is now one new file (`sms.go`) plus one `case` in
`ParseChannel` — no existing file changes.
