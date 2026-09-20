```python
# ❌ the same discriminator in send.py, validate.py and retry.py
match a.channel:
    case "email": ...
    case "slack": ...
    case _:
        raise ValueError(f"unknown channel {a.channel!r}")


# ✅ chosen once at the boundary; everything downstream tells
class Channel(Protocol):
    def send(self, a: Alert) -> None: ...
    def valid_recipient(self, recipient: str) -> bool: ...
    def retry_delay(self) -> timedelta: ...

def parse_channel(name: ChannelName) -> Channel:
    match name:                       # the ONE switch
        case ChannelName.EMAIL: return Email()
        case ChannelName.SLACK: return Slack()
        case ChannelName.PAGERDUTY: return PagerDuty()
        case _: assert_never(name)    # the completeness proof, not an "unknown" path
```

> **In Python:** the kept switch is a `match` over an enum closed by
> `case _: assert_never(x)`; a `case _:` that raises or logs is the finding. Prefer a
> dict of callables first, a `Protocol` hierarchy second, `functools.singledispatch`
> third. A positional boolean parameter is always a finding (ruff `FBT001`): make it
> keyword-only while the branches share a body, Split Flag Argument when they do not.
