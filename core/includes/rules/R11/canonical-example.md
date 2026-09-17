A notifier must deliver alerts over email, Slack, or PagerDuty. The channel is decided
by a string field, and three parts of the codebase ask which one it is.

### Before

```text
# ❌ alert/send — first copy of the discriminator
send(alert):
    switch alert.channel:
        "email":     return smtpSend(alert.recipient, renderEmail(alert))
        "slack":     return slackPost(alert.recipient, renderSlack(alert))
        "pagerduty": return pdCreateIncident(alert.recipient, alert.summary)
        otherwise:   fail "unknown channel <channel>"

# ❌ alert/validate — second copy, drifting already: nobody added pagerduty here
validRecipient(alert):
    switch alert.channel:
        "email": return alert.recipient contains "@"
        "slack": return alert.recipient starts with "#"
    return false

# ❌ alert/retry — third copy, as an if-chain this time
retryDelay(alert):
    if alert.channel == "pagerduty": return 0
    if alert.channel == "slack":     return 5 seconds
    return 1 minute
```

Three owners of one decision, already inconsistent: `validRecipient` silently returns
`false` for PagerDuty because the second copy was never updated. Adding SMS means
finding all three (and the fourth one hiding in a test helper). Every function also
carries the `otherwise` error path — the "maybe-unknown channel" concept leaks into
each call site, the behavioral twin of R1's maybe-invalid port.

### After

```text
# Channel is the behavior, not a string. Each variant is a leaf type.
Channel                      # an interface / protocol / trait with three methods
    send(alert)
    validRecipient(recipient)
    retryDelay()

# parseChannel is the ONLY place the raw string is inspected —
# the decision is made once, at the boundary, like R2's parsePort.
parseChannel(name):
    switch name:
        "email":     return Email()
        "slack":     return Slack()
        "pagerduty": return PagerDuty()
        otherwise:   fail "unknown channel <name>"

Slack
    send(alert):             return slackPost(alert.recipient, renderSlack(alert))
    validRecipient(r):       return r starts with "#"
    retryDelay():            return 5 seconds
```

The three switches are gone — call sites read `alert.channel.send(alert)`,
`alert.channel.retryDelay()`. There is no `otherwise` anywhere downstream: an `Alert`
that exists holds a `Channel` that exists, so "unknown channel" is unrepresentable
past the boundary. Adding SMS is one new type plus one case in `parseChannel` —
existing files untouched, and each channel's behavior unit-tests as a leaf with
literals. In a language without interfaces the same move is a class per variant
with a shared base, or a dispatch table from name to variant object.
