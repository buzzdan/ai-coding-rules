A notifier must deliver alerts over email, Slack, or PagerDuty. The channel is decided
by a string field, and three parts of the codebase ask which one it is.

### Before

```go
// ❌ alert/send.go — first copy of the discriminator
func Send(a Alert) error {
    switch a.Channel {
    case "email":
        return smtpSend(a.Recipient, renderEmail(a))
    case "slack":
        return slackPost(a.Recipient, renderSlack(a))
    case "pagerduty":
        return pdCreateIncident(a.Recipient, a.Summary)
    default:
        return fmt.Errorf("unknown channel %q", a.Channel)
    }
}

// ❌ alert/validate.go — second copy, drifting already: nobody added pagerduty here
func validRecipient(a Alert) bool {
    switch a.Channel {
    case "email":
        return strings.Contains(a.Recipient, "@")
    case "slack":
        return strings.HasPrefix(a.Recipient, "#")
    }
    return false
}

// ❌ alert/retry.go — third copy, as an if-chain this time
func retryDelay(a Alert) time.Duration {
    if a.Channel == "pagerduty" {
        return 0
    }
    if a.Channel == "slack" {
        return 5 * time.Second
    }
    return time.Minute
}
```

Three owners of one decision, already inconsistent: `validRecipient` silently returns
`false` for PagerDuty because the second copy was never updated. Adding SMS means
finding all three (and the fourth one hiding in a test helper). Every function also
carries the `default:` error path — the "maybe-unknown channel" concept leaks into
each call site, the behavioral twin of R1's maybe-invalid port.

### After

```go
// Channel is the behavior, not a string. Each variant is a leaf type.
type Channel interface {
    Send(a Alert) error
    ValidRecipient(recipient string) bool
    RetryDelay() time.Duration
}

// ParseChannel is the ONLY place the raw string is inspected —
// the decision is made once, at the boundary, like R2's ParsePort.
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

type Slack struct{}

func (Slack) Send(a Alert) error                { return slackPost(a.Recipient, renderSlack(a)) }
func (Slack) ValidRecipient(r string) bool      { return strings.HasPrefix(r, "#") }
func (Slack) RetryDelay() time.Duration         { return 5 * time.Second }
```

The three switches are gone — call sites read `a.Channel.Send(a)`,
`a.Channel.RetryDelay()`. There is no `default:` anywhere downstream: an `Alert` that
exists holds a `Channel` that exists, so "unknown channel" is unrepresentable past
the boundary. Adding SMS is one new type plus one `case` in `ParseChannel` — existing
files untouched, and each channel's behavior unit-tests as a leaf with literals.
Full worked study including the strategy-map variant and the rejection counter-case:
`../examples/anti-if-dispatch.md`.
