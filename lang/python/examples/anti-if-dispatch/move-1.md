Define the protocol from the union of what the copies do: `send` switches on
delivery, `valid_recipient` on addressing, `retry_delay` on retry policy — three
methods, one class per variant:

```python
# alert/channel.py
class Channel(Protocol):
    def send(self, a: Alert) -> None: ...
    def valid_recipient(self, recipient: str) -> bool: ...
    def retry_delay(self) -> timedelta: ...


class ChannelName(StrEnum):
    EMAIL = "email"
    SLACK = "slack"
    PAGERDUTY = "pagerduty"


# The single decision point. This lookup is ALLOWED — it is the one place the raw
# string may be inspected (R11), exactly as a parse classmethod is the one place a
# raw value is validated (R2). The dict is complete by a one-line test.
CHANNELS: dict[ChannelName, Channel] = {
    ChannelName.EMAIL: Email(),
    ChannelName.SLACK: Slack(),
    ChannelName.PAGERDUTY: PagerDuty(),
}


def parse_channel(name: str) -> Channel:
    return CHANNELS[ChannelName(name)]  # ValueError at the edge, nowhere else
```

```python
# alert/slack.py — each variant is a leaf class owning ALL its behavior
class Slack:
    def send(self, a: Alert) -> None:
        slack_post(a.recipient, render_slack(a))

    def valid_recipient(self, recipient: str) -> bool:
        return recipient.startswith("#")

    def retry_delay(self) -> timedelta:
        return timedelta(seconds=5)
```

`Alert` now holds a `Channel`, constructed at the boundary (the HTTP handler or
config loader calls `parse_channel` and fails fast there). The three switching sites
collapse to method calls:

```python
def send(a: Alert) -> None:
    a.channel.send(a)


def valid_recipient(a: Alert) -> bool:
    return a.channel.valid_recipient(a.recipient)


def retry_delay(a: Alert) -> timedelta:
    return a.channel.retry_delay()
```

(And once they are one-liners, the wrappers themselves usually dissolve into their
callers — the story functions call the methods directly, R3.)

What was deleted, not relocated: every `case _:` arm and every `.get` default
downstream. An `Alert` that exists holds a `Channel` that exists; "unknown channel"
is unrepresentable past `parse_channel`. Adding SMS is now one new module (`sms.py`),
one `ChannelName` member and one `CHANNELS` entry — no existing module changes.
