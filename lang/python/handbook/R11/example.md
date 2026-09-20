```python
# ❌ the same discriminator in send.py, validate.py and retry.py
match a.channel:
    case "email": ...
    case "slack": ...
    case _:
        raise ValueError(f"unknown channel {a.channel!r}")


# ✅ chosen once at the boundary; everything downstream tells
from typing import Protocol, assert_never

class Channel(Protocol):
    def send(self, a: Alert) -> None: ...
    def valid_recipient(self, recipient: str) -> bool: ...
    def retry_delay(self) -> timedelta: ...

def parse_channel(raw: str) -> Channel:
    name = ChannelName(raw)          # the raw string becomes an enum here, or raises
    match name:                      # the ONE switch
        case ChannelName.EMAIL: return Email()
        case ChannelName.SLACK: return Slack()
        case ChannelName.PAGERDUTY: return PagerDuty()
        case _: assert_never(name)   # the completeness proof, not an "unknown" path
```

> **In Python:** the kept switch is a `match` over an enum closed by
> `case _: assert_never(x)`; a `case _:` that raises or logs is the finding. Prefer a
> dict of callables first (`CHANNELS[ChannelName(raw)]`), a `Protocol` hierarchy
> second, `functools.singledispatch` third. A boolean parameter that selects a branch
> is a Split Flag Argument candidate (P1).
