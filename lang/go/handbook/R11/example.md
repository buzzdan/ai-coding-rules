```go
// ❌ the same discriminator in send.go, validate.go and retry.go
switch a.Channel {
case "email": /* ... */
case "slack": /* ... */
case "pagerduty": /* ... */
default:
    return fmt.Errorf("unknown channel %q", a.Channel)
}

// ✅ chosen once at the boundary; everything downstream tells
type Channel interface {
    Send(ctx context.Context, a Alert) error
    ValidRecipient(r string) bool
    RetryDelay() time.Duration
}

func ParseChannel(kind string) (Channel, error) // the one switch, exhaustive
```

> **In Go:** the kept switch is over a typed enum and closed by the `exhaustive`
> linter, not by a `default` that returns "unknown kind" from deep inside the logic.
> A boolean parameter that selects a branch is a Split Flag Argument candidate.
