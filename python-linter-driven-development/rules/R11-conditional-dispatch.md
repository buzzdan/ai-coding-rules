# R11 — Conditional Dispatch (Anti-IF)

## Principle

A conditional that asks what a value *is* — a type switch, or a switch/if-chain on a
kind/status/mode discriminator — may exist **once**. The second copy of that
discriminator is a missing polymorphic type: the variants want to be implementations
of an interface (or entries in a dispatch map), chosen once at the boundary, so
downstream code *tells* the value what to do instead of asking what it is. One
well-placed, exhaustive switch is not a defect; a duplicated one always is.

## Why

Every `if (new kind) { new code }` doubles the execution paths through the function —
five conditionals means 32 paths to reason about and test. Worse, kind-switches
replicate: the same `switch msg.Channel` appears in send, validate, format, and retry
code, and adding a variant means finding and editing every copy — the one you miss is
the bug that ships. The compiler cannot help: an if-chain has no notion of
completeness, so a forgotten variant falls through silently. Dispatching once —
constructing the right implementation at the boundary (`R2-self-validating-types.md`
owns "validate once at the edge"; this rule is its behavioral twin: *decide* once at
the edge) — collapses N switches into one construction site, makes each variant a
leaf that unit-tests in isolation, and turns "add a variant" into "add a type" with
zero edits to existing code. This idea comes from the Anti-IF movement (Cirillo,
2007): the enemy is not `if`, it is the duplicated kind-conditional.

## Canonical example

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
enum — it is a `match` whose last arm is `case _: assert_never(x)`, so mypy fails the
build when a variant is added but not handled; that arm is the completeness proof,
not an "unknown kind" default. Full worked study including the strategy-map variant
and the rejection counter-case: `../examples/anti-if-dispatch.md`.

## Design guidance

- **The trigger is duplication, not existence.** Count the sites that inspect the same
  discriminator. One site — keep the switch (make it exhaustive). Two or more —
  the variants are a type family; dispatch.
- **A duplicated two-way decision that produces a value is R1's, not this rule's.**
  When the repeated conditional does not *dispatch behavior* but *picks one of a fixed
  set of literals* — `scheme := "http"; if tls { scheme = "https" }` in two functions —
  the finding is R1 Q3 and the fix is Name enum strings (`type Scheme` with its
  constants and one constructor from the flag), never a helper that returns the same
  bare string. Route it to R1 and cite that move; this rule's Interface Dispatch and
  Strategy Map are for variants that behave differently, not values that spell
  differently.
- **Decide once, at the edge.** The one legitimate inspection of the raw discriminator
  is the constructor/parser that picks the implementation
  (`R2-self-validating-types.md` for the constructor discipline). Downstream code
  holds the chosen behavior and never re-asks. The corollary: a type switch over an
  interface the same package owns is always a re-ask — the decision was made when
  the value was constructed; cases that unpack the variants' fields are behavior
  asking to live on the interface (`../examples/switch-to-polymorphism.md`).
- **Dispatch requires owning the output.** An interface method can only be written
  in the package that declares the interface, and it cannot reference another
  package's underscore-prefixed types. When the switch's output format belongs to a consumer
  (a private wire request in a client package) and the variants live in a shared API
  package, the move is unavailable — and forcing it (exporting the wire type,
  per-consumer `fill<X>Request` methods on domain types) inverts the dependency.
  There the switch is the honest boundary tax: shrink it to pure dispatch (one
  converter call per case) and stop. Worked counter-case, including the fill-style
  method shape for when the move IS available:
  `../examples/switch-to-polymorphism.md`.
- **Interface vs strategy map.** Variants with several behaviors or state → interface
  with one type per variant. Variants that differ by a single function → a map
  from kind to function — a map lookup whose missing-key case is a declared absence
  is a dispatch, not a conditional. Either way the decision has one
  owner.
- **Null object over None-checks.** A scattered "if the logger is set, log" is
  the same disease with two variants. Construct a do-nothing value once; delete every
  guard. The shape follows the collaborator's type: when an interface already exists,
  a no-op implementation; when the collaborator is a concrete type, a value of that
  type doing nothing — a sink over the standard no-op writer, a clock that is the
  real clock — and **no new interface** for the sake of the no-op
  (`R6-test-only-interfaces.md`). The standard library's no-op writer is the pattern:
  a real writer that honors the contract by reporting every byte written, so a logger
  built over it needs no guard anywhere. Fits *optional* collaborators only; a required one is rejected in the constructor
  (`R2-self-validating-types.md`, "absence is a value too").
- **Flag arguments are two functions.** A boolean flag parameter — `Render(alert,
  short)` — forces every caller through a conditional the callee then unpicks. Split into `Render` and
  `RenderShort`, or make the variant a type.
- **A kept switch must be exhaustive.** When one switch over a closed enum stays
  (single site, trivial variance), name the enum (`R1-primitive-obsession.md`,
  "Name enum strings"), drop the `default`, and let the linter's exhaustiveness
  check prove completeness — the linter then does what the if-chain never could: fail the build
  when a variant is added but not handled.
- **The over-abstraction trap, dispatch edition.** An interface with one production
  implementation is R6's territory; two trivial implementations behind one switch at
  one site score LOW on R1's juiciness scorecard — keep the conditional. Conditionals
  on *state/values* (`if n > threshold`, an error check, guard clauses per
  `R3-storifying.md`) are healthy control flow, not dispatch — this rule never
  touches them.

## Fix pattern

- **Replace Duplicated Switch with Interface Dispatch**: define the interface from the
  union of what all copies of the switch do (one method per switching site is a
  starting point, then collapse); one type per variant; move each `case` body into
  its variant; introduce `ParseX(raw)` as the single decision point and
  migrate call sites to method calls. When the dispatch produces an output that
  carries fields the variants don't own (shared name/TLS on a wire request), give
  the interface a fill-style method (`fillUpdate(req *T)`) instead of a constructor —
  the caller owns the shared fields, each variant fills its own
  (`../examples/switch-to-polymorphism.md`).
- **Replace If-Chain with Strategy Map**: single-behavior variance → a package-level
  map from kind to function (or a field), the missing-key case handled at the
  boundary only.
- **Introduce Null Object**: absent-collaborator None-checks → a do-nothing value
  substituted by the constructor when none is given; delete the guards. A no-op
  implementation when an interface already exists, otherwise a value of the concrete
  type composing the standard no-op — never a new interface with one
  real implementation (R6). Optional collaborators only; required ones are rejected
  in the constructor (R2).
- **Split Flag Argument**: boolean/enum parameter that selects behavior → two named
  functions, or a variant type chosen by the caller's constructor.
- **Keep the Single Exhaustive Switch**: one site, closed enum → named enum type (R1),
  no `default`, the linter's exhaustiveness check enforcing completeness. This is the rule's
  sanctioned form — record it as the decision, not a TODO.
- New types this creates must pass R1's juiciness scorecard, land per
  `R4-helper-placement.md`, and never become test-only interfaces
  (`R6-test-only-interfaces.md`). Rejection case law — juiciness (the switch stays,
  goes exhaustive): `../examples/anti-if-dispatch.md`; dependency direction (the
  move is unavailable across the package boundary):
  `../examples/switch-to-polymorphism.md`.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Is the same discriminator inspected in more than one place?**
   Detection: list discriminators in the diff —
   `grep -nE 'match [a-zA-Z_.]+\.(type|kind|status|mode|channel|format|level)\b' $(git diff --name-only -- '*.py')`
   and if-chain forms `grep -nE 'if [a-zA-Z_.]+\.(type|kind|status|mode|channel|format|level) ==' ...`;
   then count each across the package: `grep -rnE 'match .*\.<field>|\.<field> ==|\.<field> in \(' --include='*.py' . | wc -l`.
   A `dict` of callables keyed by the field is a dispatch site too — the healthy
   one when it is the only one; a `.get(kind, fallback)` on such a dict deep in
   logic is Q3's default arm in another spelling.
   Violation: ≥2 sites inspecting one discriminator — the decision has no single
   owner. Route first to Strategy Map (a `dict[Kind, Handler]` filled once at the
   boundary), then to Interface Dispatch (a `Protocol` with one class per variant)
   when the variants carry state or several behaviors, and to
   `functools.singledispatch` only when the discriminator is the argument's own
   class.

2. **Does a type switch dispatch on concrete types outside a boundary?**
   Detection: `grep -rnE 'isinstance\([a-zA-Z_.]+, [A-Z]|case [A-Z][A-Za-z]*\(' --include='*.py' .` —
   an `isinstance` chain or a `match` with class patterns; for each hit, is it in a
   `parse`/decoder/boundary adapter, or in business logic?
   Violation: a type switch in domain logic whose cases call variant-specific
   behavior or unpack the variants' fields — the behavior belongs on the variants.
   A switch over a `Protocol` or `ABC` the *same package* owns is a violation even
   at a single site and even in a converter: the decision was already made at
   construction, and a method on each class gives the completeness proof a switch
   can't (`../examples/switch-to-polymorphism.md`). The boundary exemption applies
   only when the output format belongs to a *different* package than the cased
   types (that example's boundary counter) — there, the finding is limited to
   shrinking the switch to pure dispatch. `except` clauses matching exception
   types, and decoding foreign JSON into your own types, are not this pattern.

3. **Does a `case _:` (or trailing `else`) handle "unknown kind" away from the boundary?**
   Detection: for each `match` found in Q1, read the `case _:` arm; for each
   if-chain, the trailing `else`; for each strategy dict, any `.get(k, default)`.
   Violation: a `case _:` that raises `ValueError("unknown kind")`, logs, or
   returns a fallback deep in the call graph — the maybe-unknown concept leaked past
   construction; dispatch should have been chosen at `parse`. The one `case _:`
   that is not a finding is `case _: assert_never(x)` closing a `match` over an
   `Enum` or a `Literal`: it is the completeness proof mypy checks, not a default.
   A `match` over an `Enum` with no such arm is incomplete silently — ruff has no
   exhaustiveness rule, and mypy checks only when `assert_never` asks it to — so
   the missing arm is itself a finding under Keep the Single Exhaustive Switch.

4. **Does a boolean parameter select between behaviors?**
   Detection: `grep -nE 'def .*\(.*\b[a-z_]+: bool' $(git diff --name-only -- '*.py')`,
   and ruff `FBT001` (boolean positional parameter) / `FBT003` (boolean positional
   call argument) where the repository enables them; check whether the function
   branches on the flag near the top.
   Violation: a positional boolean parameter is always the finding — the lint-fixer
   makes it keyword-only (`def send(a: Alert, *, dry_run: bool = False)`), which is
   the mechanical half. A keyword-only boolean stays when its two branches share
   their body and differ in one step; when they share little, Split Flag Argument
   into two named functions.

5. **Inverse — is a NEW dispatch abstraction in the diff unearned?**
   Detection: for each new `Protocol`/ABC hierarchy, strategy dict or
   `singledispatch` in the diff, count production implementations/entries and the
   number of sites the old conditional occupied (`git log -p` or the pre-diff file).
   Violation: one switching site with trivial variance replaced by a class
   hierarchy — score it (R1 scorecard); if LOW, the finding is the *extraction*, and
   the fix is Keep the Single Exhaustive Switch: one `match` over the `Enum`, closed
   by `case _: assert_never(x)`. A Protocol whose second implementation exists only
   in tests is an R6 violation, not a dispatch win.
