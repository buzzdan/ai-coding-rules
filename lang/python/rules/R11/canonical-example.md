A notifier must deliver alerts over email, Slack, or PagerDuty. The channel is decided
by a string field, and three parts of the codebase ask which one it is.

### Before

```python
# ❌ alert/send.py — first copy of the discriminator
def send(a: Alert) -> None:
    match a.channel:
        case "email":
            smtp_send(a.recipient, render_email(a))
        case "slack":
            slack_post(a.recipient, render_slack(a))
        case "pagerduty":
            pd_create_incident(a.recipient, a.summary)
        case _:
            raise ValueError(f"unknown channel {a.channel!r}")


# ❌ alert/validate.py — second copy, drifting already: nobody added pagerduty here
def valid_recipient(a: Alert) -> bool:
    if a.channel == "email":
        return "@" in a.recipient
    if a.channel == "slack":
        return a.recipient.startswith("#")
    return False


# ❌ alert/retry.py — third copy
def retry_delay(a: Alert) -> timedelta:
    if a.channel == "pagerduty":
        return timedelta(0)
    if a.channel == "slack":
        return timedelta(seconds=5)
    return timedelta(minutes=1)
```

Three owners of one decision, already inconsistent: `valid_recipient` silently returns
`False` for PagerDuty because the second copy was never updated. Adding SMS means
finding all three (and the fourth one hiding in a test helper). The first function
also carries the `case _:` error path — the "maybe-unknown channel" concept leaks
into a call site, the behavioural twin of R1's maybe-invalid port.

### After

```python
# Channel is the behaviour, not a string. Each variant is a leaf type.
class Channel(Protocol):
    def send(self, a: Alert) -> None: ...
    def valid_recipient(self, recipient: str) -> bool: ...
    def retry_delay(self) -> timedelta: ...


class ChannelName(StrEnum):
    EMAIL = "email"
    SLACK = "slack"
    PAGERDUTY = "pagerduty"


# The ONLY place the raw string is inspected — the decision is made once, at the
# boundary, like R2's Port. The dictionary is complete by a one-line test.
CHANNELS: dict[ChannelName, Channel] = {
    ChannelName.EMAIL: Email(),
    ChannelName.SLACK: Slack(),
    ChannelName.PAGERDUTY: PagerDuty(),
}


def parse_channel(raw: str) -> Channel:
    return CHANNELS[ChannelName(raw)]        # ValueError / KeyError at the edge, nowhere else


class Slack:
    def send(self, a: Alert) -> None:
        slack_post(a.recipient, render_slack(a))

    def valid_recipient(self, recipient: str) -> bool:
        return recipient.startswith("#")

    def retry_delay(self) -> timedelta:
        return timedelta(seconds=5)
```

The three switches are gone — call sites read `a.channel.send(a)`,
`a.channel.retry_delay()`. There is no `case _:` raising anywhere downstream: an
`Alert` that exists holds a `Channel` that exists, so "unknown channel" is
unrepresentable past the boundary. Adding SMS is one new class plus one entry in
`CHANNELS` — existing modules untouched, and each channel's behaviour unit-tests as a
leaf with literals. Where one switch legitimately stays — a single site over a closed
enum — it is a `match` whose last arm is `case _: assert_never(x)`, so ty fails the
build when a variant is added but not handled; that arm is the completeness proof,
not an "unknown kind" default. Full worked study including the strategy-map variant
and the rejection counter-case: `../examples/anti-if-dispatch.md`.
