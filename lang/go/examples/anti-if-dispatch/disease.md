The alert feature delivers over email, Slack, or PagerDuty. `Alert.Channel` is a raw
string (already an R1 smell), and three sites ask what it is:

```go
// ❌ alert/send.go
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

// ❌ alert/validate.go — drifted: pagerduty was never added here
func validRecipient(a Alert) bool {
    switch a.Channel {
    case "email":
        return strings.Contains(a.Recipient, "@")
    case "slack":
        return strings.HasPrefix(a.Recipient, "#")
    }
    return false
}

// ❌ alert/retry.go — the same decision wearing an if-chain
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
