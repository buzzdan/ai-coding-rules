# Anti-IF Dispatch Case: One Decision, One Owner

Demonstrates: R11 (edges into R1, R2, R6)

A worked study of the R11 moves on a realistic alert-notification slice: a string
discriminator inspected in three files becomes an interface chosen once at the
boundary; a single-function variance becomes a strategy map instead; and the inverse
case — where the skeptic kills the extraction and the switch *stays* — is worked to
its cheaper alternative. The compact excerpt lives in
`../rules/R11-conditional-dispatch.md`; this file is the full case law.

## The disease: a decision with three owners

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

Why this is a defect and not a style choice:

- **The drift already happened.** `valid_recipient` returns `False` for
  `"pagerduty"` — not by decision, but because the second copy of the switch was not
  in view when the third channel landed. Duplicated discriminators drift the same way
  duplicated validation predicates drift (R1's Q2).
- **Adding SMS is a scavenger hunt.** Three known sites, plus whatever a grep misses
  (test helpers, a metrics label formatter). Neither ruff nor ty flags any of them:
  an if-chain has no completeness, a `match` on a `str` has nothing to be exhaustive
  over, and a `.get(kind, default)` swallows the new case silently.
- **"Unknown channel" leaks everywhere.** Every switching site carries the
  `case _:`/fall-through arm, so every function's signature and tests carry the
  maybe-unknown concept — the behavioral twin of R1's maybe-invalid port.
- **Nothing unit-tests in isolation.** Slack's recipient rule is only reachable by
  driving `valid_recipient` with a fully built `Alert`.

## Move 1 — Replace Duplicated Switch with Interface Dispatch

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

**R6 check, answered explicitly:** this interface is *earned* — it has three
production implementations on day one. R6 forbids interfaces whose only second
implementer is a test double; a dispatch interface born with one variant "for the
future" fails that test and should stay a switch until the second variant is real.

### The testing payoff

Each variant unit-tests as a leaf with literals — no `Alert` construction, no
switch-driving:

```python
def test_slack_valid_recipient() -> None:
    assert alert.Slack().valid_recipient("#oncall")
    assert not alert.Slack().valid_recipient("oncall")


def test_parse_channel_rejects_unknown() -> None:
    with pytest.raises(ValueError):
        alert.parse_channel("carrier-pigeon")


def test_every_channel_name_has_a_channel() -> None:
    assert set(alert.CHANNELS) == set(alert.ChannelName)
```

The drift bug (`pagerduty` missing from `valid_recipient`) can no longer be written:
there is no second place to forget, and the last test fails the moment a
`ChannelName` member has no entry.

## Move 2 — Replace If-Chain with Strategy Map

Not every variance deserves an interface. Suppose only *rendering* varies by an
output format, in one behavioral dimension:

```python
# ❌ before: if-chain in the middle of business logic
def render(a: Alert, fmt: str) -> str:
    if fmt == "json":
        return render_json(a)
    if fmt == "text":
        return render_text(a)
    return render_markdown(a)  # silent default — is "yaml" markdown? nobody decided
```

One behavior → a map, not three types:

```python
class Format(StrEnum):
    JSON = "json"
    TEXT = "text"
    MARKDOWN = "markdown"


RENDERERS: dict[Format, Callable[[Alert], str]] = {
    Format.JSON: render_json,
    Format.TEXT: render_text,
    Format.MARKDOWN: render_markdown,
}


def parse_format(raw: str) -> Format:
    return Format(raw)  # ValueError for "yaml", here and nowhere else


def render(a: Alert, f: Format) -> str:
    return RENDERERS[f](a)
```

The lookup *is* the dispatch; the "is this a known format" question is asked once, in
`parse_format`, at the boundary, and `RENDERERS[f]` never needs a `.get` default
because a `Format` that exists is a key that exists. The silent markdown default — an
undecided decision — became an explicit error. (The dict is module-level immutable
data, the sanctioned shape under R8; naming the enum is R1's "Name enum strings"
move.)

## Move 3 — the rejection: when the switch stays

The skeptic's side of R11, worked honestly. The same codebase has this:

```python
# alert/severity.py — the ONLY site that inspects Severity
class Severity(Enum):
    INFO = auto()
    WARNING = auto()
    CRITICAL = auto()

    def color(self) -> str:
        match self:
            case Severity.INFO:
                return "blue"
            case Severity.WARNING:
                return "yellow"
            case Severity.CRITICAL:
                return "red"
        return ""
```

A dispatch-happy reading says: three variants, extract a `Severity` protocol with
`Info`, `Warning`, `Critical` classes. Score it before moving (R1 scorecard, via the
over-abstraction skeptic):

- Duplication of the discriminator: **1 site** (grep `match .*severity` → one hit) — +0
- Behavioral variance: one method, returns a constant string — trivial — +0
- Would the protocol be earned (R6)? Three implementations, but each is an empty
  class wrapping one literal — ceremony

Verdict: **REFUTED.** The extraction would turn 12 readable lines into three files
and an interface for zero deletion — no duplicated switch exists to delete. The
cheaper alternative is R11's sanctioned form, **Keep the Single Exhaustive Switch**:

```python
    def color(self) -> str:
        match self:
            case Severity.INFO:
                return "blue"
            case Severity.WARNING:
                return "yellow"
            case Severity.CRITICAL:
                return "red"
            case _:
                assert_never(self)  # exhaustive: ty fails when a Severity is added unhandled
```

The `case _: assert_never(self)` arm is not an unknown-kind default — it is the
completeness proof. ty narrows `self` through the arms; if a member is left
unhandled, the type reaching `assert_never` is not `Never` and the check fails at
this `match`. Adding `Severity.FATAL` now fails `ty` instead of falling through to
`""`. That is the whole benefit, at none of the cost. (ruff has no exhaustiveness
rule; without the `assert_never` arm the `match` is incomplete silently.)

**The dividing line, restated:** dispatch is bought with the *deletion of duplicated
decisions*. Three sites collapsed to one boundary — clear win (Move 1). One
single-dimension variance — a map (Move 2). One site, trivial variance — the switch
stays, made exhaustive (Move 3). If nothing gets deleted, the abstraction is
ceremony.
