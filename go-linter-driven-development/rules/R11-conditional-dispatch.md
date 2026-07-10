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

```go
// ❌ alert/send.go — first copy of the discriminator
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

// ❌ alert/validate.go — second copy, drifting already: nobody added pagerduty here
func validRecipient(a Alert) bool {
    switch a.Channel {
    case "email":
        return strings.Contains(a.Recipient, "@")
    case "slack":
        return strings.HasPrefix(a.Recipient, "#")
    }
    return false
}

// ❌ alert/retry.go — third copy, as an if-chain this time
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

Three owners of one decision, already inconsistent: `validRecipient` silently returns
`false` for PagerDuty because the second copy was never updated. Adding SMS means
finding all three (and the fourth one hiding in a test helper). Every function also
carries the `default:` error path — the "maybe-unknown channel" concept leaks into
each call site, the behavioral twin of R1's maybe-invalid port.

### After

```go
// Channel is the behavior, not a string. Each variant is a leaf type.
type Channel interface {
    Send(a Alert) error
    ValidRecipient(recipient string) bool
    RetryDelay() time.Duration
}

// ParseChannel is the ONLY place the raw string is inspected —
// the decision is made once, at the boundary, like R2's ParsePort.
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

type Slack struct{}

func (Slack) Send(a Alert) error                { return slackPost(a.Recipient, renderSlack(a)) }
func (Slack) ValidRecipient(r string) bool      { return strings.HasPrefix(r, "#") }
func (Slack) RetryDelay() time.Duration         { return 5 * time.Second }
```

The three switches are gone — call sites read `a.Channel.Send(a)`,
`a.Channel.RetryDelay()`. There is no `default:` anywhere downstream: an `Alert` that
exists holds a `Channel` that exists, so "unknown channel" is unrepresentable past
the boundary. Adding SMS is one new type plus one `case` in `ParseChannel` — existing
files untouched, and each channel's behavior unit-tests as a leaf with literals.
Full worked study including the strategy-map variant and the rejection counter-case:
`../examples/anti-if-dispatch.md`.

## Design guidance

- **The trigger is duplication, not existence.** Count the sites that inspect the same
  discriminator. One site — keep the switch (make it exhaustive). Two or more —
  the variants are a type family; dispatch.
- **Decide once, at the edge.** The one legitimate inspection of the raw discriminator
  is the constructor/parser that picks the implementation
  (`R2-self-validating-types.md` for the constructor discipline). Downstream code
  holds the chosen behavior and never re-asks. The corollary: a type switch over an
  interface the same package owns is always a re-ask — the decision was made when
  the value was constructed; cases that unpack the variants' fields are behavior
  asking to live on the interface (`../examples/switch-to-polymorphism.md`).
- **Dispatch requires owning the output.** An interface method can only be written
  in the package that declares the interface, and it cannot reference another
  package's unexported types. When the switch's output format belongs to a consumer
  (a private wire request in a client package) and the variants live in a shared API
  package, the move is unavailable — and forcing it (exporting the wire type,
  per-consumer `fill<X>Request` methods on domain types) inverts the dependency.
  There the switch is the honest boundary tax: shrink it to pure dispatch (one
  converter call per case) and stop. Worked counter-case, including the fill-style
  method shape for when the move IS available:
  `../examples/switch-to-polymorphism.md`.
- **Interface vs strategy map.** Variants with several behaviors or state → interface
  with one type per variant. Variants that differ by a single function → a map
  (`var renderers = map[Format]func(Alert) string{...}`) — a map lookup with a
  comma-ok check is a dispatch, not a conditional. Either way the decision has one
  owner.
- **Null object over nil-checks.** A scattered `if x != nil { x.Log(...) }` is the
  same disease with two variants. Construct a do-nothing implementation
  (`type NopLogger struct{}`) once; delete every guard. (R2's "nil is not a value"
  covers the constructor side.)
- **Flag arguments are two functions.** `func Render(a Alert, short bool)` forces
  every caller through a conditional the callee then unpicks. Split into `Render` and
  `RenderShort`, or make the variant a type.
- **A kept switch must be exhaustive.** When one switch over a closed enum stays
  (single site, trivial variance), name the enum (`R1-primitive-obsession.md`,
  "Name enum strings"), drop the `default`, and let the `exhaustive` linter prove
  completeness — the linter then does what the if-chain never could: fail the build
  when a variant is added but not handled.
- **The over-abstraction trap, dispatch edition.** An interface with one production
  implementation is R6's territory; two trivial implementations behind one switch at
  one site score LOW on R1's juiciness scorecard — keep the conditional. Conditionals
  on *state/values* (`if n > threshold`, `if err != nil`, guard clauses per
  `R3-storifying.md`) are healthy control flow, not dispatch — this rule never
  touches them.

## Fix pattern

- **Replace Duplicated Switch with Interface Dispatch**: define the interface from the
  union of what all copies of the switch do (one method per switching site is a
  starting point, then collapse); one type per variant; move each `case` body into
  its variant; introduce `ParseX(raw) (X, error)` as the single decision point and
  migrate call sites to method calls. When the dispatch produces an output that
  carries fields the variants don't own (shared name/TLS on a wire request), give
  the interface a fill-style method (`fillUpdate(req *T)`) instead of a constructor —
  the caller owns the shared fields, each variant fills its own
  (`../examples/switch-to-polymorphism.md`).
- **Replace If-Chain with Strategy Map**: single-behavior variance → package-level
  `map[Kind]func(...)` (or a field), comma-ok on lookup at the boundary only.
- **Introduce Null Object**: absent-collaborator nil-checks → a no-op implementation
  constructed by default; delete the guards.
- **Split Flag Argument**: boolean/enum parameter that selects behavior → two named
  functions, or a variant type chosen by the caller's constructor.
- **Keep the Single Exhaustive Switch**: one site, closed enum → named enum type (R1),
  no `default`, `exhaustive` linter enforcing completeness. This is the rule's
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
   `grep -nE 'switch [a-zA-Z_.]+\.(Type|Kind|Status|Mode|Channel|Format|Level)\b' $(git diff --name-only -- '*.go')`
   and if-chain forms `grep -nE 'if [a-zA-Z_.]+\.(Type|Kind|Status|Mode|Channel|Format|Level) ==' ...`;
   then count each across the package: `grep -rn 'switch .*\.<Field>' --include='*.go' . | wc -l` (plus `== ` comparisons on the same field).
   Violation: ≥2 sites inspecting one discriminator — the decision has no single
   owner; route to Interface Dispatch or Strategy Map.

2. **Does a type switch dispatch on concrete types outside a boundary?**
   Detection: `grep -rn 'switch .* := .*\.(type)' --include='*.go' .` — for each hit,
   is it in a `ParseX`/decoder/boundary adapter, or in business logic?
   Violation: a type switch in domain logic whose cases call variant-specific
   behavior or unpack the variants' fields — the behavior belongs on the variants.
   A switch over an interface the *same package* owns is a violation even at a
   single site and even in a converter: the decision was already made at
   construction, and interface satisfaction gives the completeness proof a
   switch can't (`../examples/switch-to-polymorphism.md`). The boundary exemption
   applies only when the output format belongs to a *different* package than the
   cased types (that example's boundary counter) — there, the finding is limited
   to shrinking the switch to pure dispatch. `errors.As`/`errors.Is` chains and
   decode/unmarshal of foreign types are not this pattern.

3. **Does a `default:` (or trailing `else`) handle "unknown kind" away from the boundary?**
   Detection: for each switch found in Q1, check the `default` arm for
   `errors.New`/`fmt.Errorf`/panic on an unknown-kind message.
   Violation: unknown-kind errors deep in the call graph — the maybe-unknown concept
   leaked past construction; dispatch should have been chosen at `ParseX`.

4. **Does a boolean parameter select between behaviors?**
   Detection: `grep -nE 'func .*\(.*\b(is|use|with|enable|skip)[A-Za-z]* bool' $(git diff --name-only -- '*.go')`;
   check whether the function branches on it near the top.
   Violation: a flag argument whose branches share little code — Split Flag Argument.

5. **Inverse — is a NEW dispatch abstraction in the diff unearned?**
   Detection: for each new interface/strategy map in the diff, count production
   implementations/entries and the number of sites the old conditional occupied
   (`git log -p` or the pre-diff file).
   Violation: one switching site with trivial variance replaced by an interface —
   score it (R1 scorecard); if LOW, the finding is the *extraction*, and the fix is
   Keep the Single Exhaustive Switch. An interface whose second implementation exists
   only in tests is an R6 violation, not a dispatch win.
