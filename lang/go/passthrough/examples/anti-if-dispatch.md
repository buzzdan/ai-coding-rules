# Anti-IF Dispatch Case: One Decision, One Owner

Demonstrates: R11 (edges into R1, R2, R6)

A worked study of the R11 moves on a realistic alert-notification slice: a string
discriminator inspected in three files becomes an interface chosen once at the
boundary; a single-function variance becomes a strategy map instead; and the inverse
case — where the skeptic kills the extraction and the switch *stays* — is worked to
its cheaper alternative. The compact excerpt lives in
`../rules/R11-conditional-dispatch.md`; this file is the full case law.

## The disease: a decision with three owners

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

Why this is a defect and not a style choice:

- **The drift already happened.** `validRecipient` returns `false` for `"pagerduty"`
  — not by decision, but because the second copy of the switch was not in view when
  the third channel landed. Duplicated discriminators drift the same way duplicated
  validation predicates drift (R1's Q2).
- **Adding SMS is a scavenger hunt.** Three known sites, plus whatever a grep misses
  (test helpers, a metrics label formatter). The compiler flags none of them: an
  if-chain has no completeness, and a switch with a `default` swallows the new case
  silently.
- **"Unknown channel" leaks everywhere.** Every switching site carries the
  `default:`/fall-through arm, so every function's signature and tests carry the
  maybe-unknown concept — the behavioral twin of R1's maybe-invalid port.
- **Nothing unit-tests in isolation.** Slack's recipient rule is only reachable by
  driving `validRecipient` with a fully built `Alert`.

## Move 1 — Replace Duplicated Switch with Interface Dispatch

Define the interface from the union of what the copies do: `Send` switches on
delivery, `validRecipient` on addressing, `retryDelay` on retry policy — three
methods, one type per variant:

```go
// alert/channel.go
type Channel interface {
    Send(a Alert) error
    ValidRecipient(recipient string) bool
    RetryDelay() time.Duration
}

// ParseChannel is the single decision point. This switch is ALLOWED —
// it is the one place the raw string may be inspected (R11), exactly as
// a ParseX constructor is the one place a raw value is validated (R2).
func ParseChannel(name string) (Channel, error) {
    switch name {
    case "email":
        return Email{}, nil
    case "slack":
        return Slack{}, nil
    case "pagerduty":
        return PagerDuty{}, nil
    default:
        return nil, fmt.Errorf("unknown channel %q", name)
    }
}
```

```go
// alert/slack.go — each variant is a leaf type owning ALL its behavior
type Slack struct{}

func (Slack) Send(a Alert) error           { return slackPost(a.Recipient, renderSlack(a)) }
func (Slack) ValidRecipient(r string) bool { return strings.HasPrefix(r, "#") }
func (Slack) RetryDelay() time.Duration    { return 5 * time.Second }
```

`Alert` now holds a `Channel`, constructed at the boundary (the HTTP handler or
config loader calls `ParseChannel` and fails fast there). The three switching sites
collapse to method calls:

```go
func Send(a Alert) error            { return a.Channel.Send(a) }
func validRecipient(a Alert) bool   { return a.Channel.ValidRecipient(a.Recipient) }
func retryDelay(a Alert) time.Duration { return a.Channel.RetryDelay() }
```

(And once they are one-liners, the wrappers themselves usually dissolve into their
callers — the story functions call the methods directly, R3.)

What was deleted, not relocated: every `default:` arm downstream. An `Alert` that
exists holds a `Channel` that exists; "unknown channel" is unrepresentable past
`ParseChannel`. Adding SMS is now one new file (`sms.go`) plus one `case` in
`ParseChannel` — no existing file changes.

**R6 check, answered explicitly:** this interface is *earned* — it has three
production implementations on day one. R6 forbids interfaces whose only second
implementer is a test double; a dispatch interface born with one variant "for the
future" fails that test and should stay a switch until the second variant is real.

### The testing payoff

Each variant unit-tests as a leaf with literals — no `Alert` construction, no
switch-driving:

```go
func TestSlack_ValidRecipient(t *testing.T) {
    assert.True(t, alert.Slack{}.ValidRecipient("#oncall"))
    assert.False(t, alert.Slack{}.ValidRecipient("oncall"))
}

func TestParseChannel_Unknown(t *testing.T) {
    _, err := alert.ParseChannel("carrier-pigeon")
    require.Error(t, err)
}
```

The drift bug (`pagerduty` missing from `validRecipient`) can no longer be written:
there is no second place to forget.

## Move 2 — Replace If-Chain with Strategy Map

Not every variance deserves an interface. Suppose only *rendering* varies by an
output format, in one behavioral dimension:

```go
// ❌ before: if-chain in the middle of business logic
func render(a Alert, format string) string {
    if format == "json" {
        return renderJSON(a)
    }
    if format == "text" {
        return renderText(a)
    }
    return renderMarkdown(a) // silent default — is "yaml" markdown? nobody decided
}
```

One behavior → a map, not three types:

```go
type Format string

const (
    FormatJSON     Format = "json"
    FormatText     Format = "text"
    FormatMarkdown Format = "markdown"
)

var renderers = map[Format]func(Alert) string{
    FormatJSON:     renderJSON,
    FormatText:     renderText,
    FormatMarkdown: renderMarkdown,
}

func ParseFormat(raw string) (Format, error) {
    if _, ok := renderers[Format(raw)]; !ok {
        return "", fmt.Errorf("unknown format %q", raw)
    }
    return Format(raw), nil
}

func render(a Alert, f Format) string { return renderers[f](a) }
```

The lookup *is* the dispatch; the comma-ok check lives once, in `ParseFormat`, at the
boundary. The silent markdown default — an undecided decision — became an explicit
error. (The map is package-level immutable data, the sanctioned shape under R8;
naming the enum is R1's "Name enum strings" move.)

## Move 3 — the rejection: when the switch stays

The skeptic's side of R11, worked honestly. The same codebase has this:

```go
// alert/severity.go — the ONLY site that inspects Severity
func (s Severity) Color() string {
    switch s {
    case SeverityInfo:
        return "blue"
    case SeverityWarning:
        return "yellow"
    case SeverityCritical:
        return "red"
    }
    return ""
}
```

A dispatch-happy reading says: three variants, extract `type Severity interface`
with `Info`, `Warning`, `Critical` types. Score it before moving (R1 scorecard, via
the over-abstraction skeptic):

- Duplication of the discriminator: **1 site** (grep `switch .*Severity` → one hit) — +0
- Behavioral variance: one method, returns a constant string — trivial — +0
- Would the interface be earned (R6)? Three implementations, but each is an empty
  struct wrapping one literal — ceremony

Verdict: **REFUTED.** The extraction would turn 12 readable lines into three files
and an interface for zero deletion — no duplicated switch exists to delete. The
cheaper alternative is R11's sanctioned form, **Keep the Single Exhaustive Switch**:

```go
func (s Severity) Color() string {
    switch s { // exhaustive: linter fails the build when a Severity is added unhandled
    case SeverityInfo:
        return "blue"
    case SeverityWarning:
        return "yellow"
    case SeverityCritical:
        return "red"
    }
    return ""
}
```

with `exhaustive` enabled in `.golangci.yaml`. Now the linter provides what dispatch
would have: adding `SeverityFatal` fails the build at this switch instead of falling
through to `""`. That is the whole benefit, at none of the cost.

**The dividing line, restated:** dispatch is bought with the *deletion of duplicated
decisions*. Three sites collapsed to one boundary — clear win (Move 1). One
single-dimension variance — a map (Move 2). One site, trivial variance — the switch
stays, made exhaustive (Move 3). If nothing gets deleted, the abstraction is
ceremony.
