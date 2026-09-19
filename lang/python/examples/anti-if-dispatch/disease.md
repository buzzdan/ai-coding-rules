The alert feature delivers over email, Slack, or PagerDuty. `Alert.channel` is a raw
string (already an R1 smell), and three sites ask what it is:

```python
# ❌ alert/send.py
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


# ❌ alert/validate.py — drifted: pagerduty was never added here
def valid_recipient(a: Alert) -> bool:
    if a.channel == "email":
        return "@" in a.recipient
    if a.channel == "slack":
        return a.recipient.startswith("#")
    return False


# ❌ alert/retry.py — the same decision wearing a dict lookup with a default
RETRY_DELAYS = {"pagerduty": timedelta(0), "slack": timedelta(seconds=5)}


def retry_delay(a: Alert) -> timedelta:
    return RETRY_DELAYS.get(a.channel, timedelta(minutes=1))
```
