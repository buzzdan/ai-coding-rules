```text
# ❌ the same discriminator in send, validate and retry
send(alert):
    switch alert.channel:
        "email":   ...
        "slack":   ...
        otherwise: fail "unknown channel <channel>"

# ✅ chosen once at the boundary; everything downstream tells
Channel                            # an interface / protocol / trait
    send(alert)
    validRecipient(recipient)
    retryDelay()
parseChannel(raw):                 # the ONE place the raw string is inspected
    switch raw:
        "email":     return Email()
        "slack":     return Slack()
        "pagerduty": return PagerDuty()
        otherwise:   fail "unknown channel <raw>"
```

> **Spelling:** the kept switch is over a closed set the compiler or the linter can
> prove exhaustive, an enum, a sealed type, a tagged union, and it is closed by that
> proof, not by an `otherwise` that returns "unknown kind" from deep inside the
> logic. Prefer a dispatch table from name to variant first, an interface or trait
> per variant second; in a language without interfaces, a class per variant with a
> shared base. A boolean parameter that selects a branch is a Split Flag Argument
> candidate.
