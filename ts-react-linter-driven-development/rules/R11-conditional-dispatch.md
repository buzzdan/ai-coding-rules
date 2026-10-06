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

A notifier must deliver alerts over email, Slack, or a webhook. The channel is decided
by a string field, and three parts of the codebase ask which one it is.

### Before

```tsx
// ❌ src/pages/Alerts/NotifyPanel.tsx — first copy of the discriminator
function NotifyPanel({ alert }: Readonly<{ alert: Alert }>) {
  const send = (): Promise<void> => {
    switch (alert.channel) {
      case 'email':
        return sendEmail(alert.recipient, renderEmail(alert))
      case 'slack':
        return postSlack(alert.recipient, renderSlack(alert))
      case 'webhook':
        return postJson(alert.recipient, alert.summary)
      default:
        return Promise.reject(new Error(`unknown channel ${alert.channel}`))   // "unknown channel" decided here, again
    }
  }
  return <SendButton onSend={send} />
}

// ❌ src/pages/Alerts/validateChannel.ts — second copy, drifting already: nobody added webhook here
export function validateChannel(alert: Alert): boolean {
  if (alert.channel === 'email') return alert.recipient.includes('@')
  if (alert.channel === 'slack') return alert.recipient.startsWith('#')
  return false
}

// ❌ src/services/alertsApi.ts — third copy
export function retryPolicyFor(alert: Alert): RetryPolicy {
  if (alert.channel === 'webhook') return NO_RETRY
  if (alert.channel === 'slack') return { attempts: 3, baseDelayMs: 5_000 }
  return { attempts: 3, baseDelayMs: 60_000 }
}
```

Three owners of one decision, already inconsistent: `validateChannel` silently returns
`false` for a webhook because the second copy was never updated. Adding SMS means
finding all three (and the fourth one hiding in a test helper). The component's switch
also carries the `default:` arm (in a render switch it is `default: return null`) — the
"maybe-unknown channel" concept leaks into a component, the behavioural twin of R1's
maybe-invalid port.

### After

```tsx
// Channel is the behaviour, not a string. Each variant is a leaf object.
export type Channel = 'email' | 'slack' | 'webhook'

export interface ChannelSender {
  send(a: Alert): Promise<void>
  validate(recipient: string): boolean
  retryPolicy(): RetryPolicy
}

const slackSender: ChannelSender = {
  send: (a) => postSlack(a.recipient, renderSlack(a)),
  validate: (recipient) => recipient.startsWith('#'),
  retryPolicy: () => ({ attempts: 3, baseDelayMs: 5_000 }),
}

// The ONLY place the raw string is inspected — the decision is made once, at the
// boundary, like R2's parsePort. The Record is complete or it does not compile.
const CHANNEL_SENDERS: Record<Channel, ChannelSender> = {
  email: emailSender,
  slack: slackSender,
  webhook: webhookSender,
}

export function parseChannel(raw: string): ChannelSender {
  if (!isChannel(raw)) throw new ApiError(`unknown channel ${raw}`)   // thrown at the edge, nowhere else
  return CHANNEL_SENDERS[raw]
}

function NotifyPanel({ alert }: Readonly<{ alert: Alert }>) {
  return <SendButton onSend={() => alert.channel.send(alert)} />
}
```

The three switches are gone — call sites read `alert.channel.send(alert)`,
`alert.channel.validate(…)`, `alert.channel.retryPolicy()`. There is no `default:`
arm anywhere downstream: an `Alert` that exists holds a `ChannelSender` that exists,
so "unknown channel" is unrepresentable past the boundary. Adding SMS is one new
object plus one entry in `CHANNEL_SENDERS` — existing modules untouched, `tsc`
refusing to build until the entry exists, and each channel's behaviour unit-tests as
a leaf with literals. Where one switch legitimately stays — a single site over a
closed union — it is a `switch` whose `default` arm is `return assertNever(channel)`,
so `tsc` fails the build when a variant is added but not handled; that arm is the
completeness proof, not an "unknown kind" default. The component form of the flag
argument is the boolean prop: `<Panel isCompact isInline showHeader />` is three
switches the caller sets and the component unpicks — Split Flag Argument into two
components, or one `variant: 'compact' | 'inline' | 'full'` union when the flags
exclude each other. Full worked study including the strategy-map variant and the
rejection counter-case: `../examples/anti-if-dispatch.md`.

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
  package's internal types. When the switch's output format belongs to a consumer
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
- **Null object over undefined-checks.** A scattered "if the logger is set, log" is
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
- **Introduce Null Object**: absent-collaborator undefined-checks → a do-nothing value
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
   Detect-grep: `switch \([a-zA-Z_.]+\.(type|kind|status|mode|channel|format|level|variant)\)|\.(type|kind|status|mode|channel|format|level|variant) === '|\(\(\) => \{`
   Detection: the hits list the diff's discriminators — `switch` forms, if-chain
   and ternary forms, and the IIFE in a render tree; then count each across the repository: `grep -rnE "switch \(.*\.<field>\)|\.<field> === '" --include='*.ts' --include='*.tsx' --exclude-dir=node_modules . | wc -l`.
   A `Record<Kind, …>` of handlers or components keyed by the field is a dispatch
   site too — the healthy one when it is the only one; a `MAP[kind] ?? fallback`
   deep in logic is Q3's default arm in another spelling. An IIFE in a render tree
   — `{(() => { switch (alert.kind) { … } })()}` — is a switch site in parentheses:
   the last alternative lists them, each counts toward the discriminator's site
   total, and the fix is the `Record<Kind, …>` lookup or a named component.
   Violation: ≥2 sites inspecting one discriminator — the decision has no single
   owner. Route first to Strategy Map (a `Record<Kind, Handler>` — for rendering, a
   `Record<Kind, ComponentType<…>>` — filled once at the boundary), then to
   Interface Dispatch (an interface with one object per variant) when the variants
   carry state or several behaviours, and to a class hierarchy last.

2. **Does a type switch dispatch on concrete types outside a boundary?**
   Detect-grep: `instanceof [A-Z]|'[a-zA-Z]+' in [a-zA-Z_.]+\)|typeof [a-zA-Z_.]+ === '(string|number|object)'`
   Detection: an `instanceof` chain, an `in` chain or a `typeof` chain; for each hit, is it in
   a `parse*`/type-guard/boundary adapter, or in business logic or a render?
   Violation: a type switch in domain logic whose cases call variant-specific
   behavior or unpack the variants' fields — the behavior belongs on the variants.
   An `instanceof` chain over classes the *same module* owns is a violation even
   at a single site and even in a converter: the decision was already made at
   construction, and a method on each class (or an entry per variant in the
   `Record`) gives the completeness proof a chain can't
   (`../examples/switch-to-polymorphism.md`). The boundary exemption applies only
   when the output format belongs to a *different* package than the cased types
   (that example's boundary counter) — there, the finding is limited to shrinking
   the switch to pure dispatch. Type guards in `src/types/typeGuards.ts` narrowing
   `unknown` at the API boundary, `catch` blocks narrowing an `error`, and
   `instanceof` on a dependency's classes are not this pattern.

3. **Does a `default:` (or trailing `else`) handle "unknown kind" away from the boundary?**
   Detect: judgment
   Detection: for each `switch` found in Q1, read the `default` arm; for each
   if-chain, the trailing `return`; for each `Record` lookup, any `?? fallback`.
   Violation: a `default: return null` in a render switch, a `default: throw new
   Error('unknown kind')`, a logged fallback deep in the call graph — the
   maybe-unknown concept leaked past construction; dispatch should have been chosen
   at `parse*`. The one `default` that is not a finding is `default: return
   assertNever(x)` (or `x satisfies never`) closing a switch over a union: it is the
   completeness proof `tsc` checks, not a default. A switch over a union with no
   such arm is incomplete silently — a missing case falls through to `undefined`
   unless `@typescript-eslint/switch-exhaustiveness-check` is configured — so the
   missing arm is itself a finding under Keep the Single Exhaustive Switch.

4. **Does a boolean parameter select between behaviors?**
   Detect-grep: `\b(is|has|show|hide|use|with|enable|skip|as)[A-Z][A-Za-z]*\??: boolean|function [a-zA-Z]+\([^)]*: boolean`
   Detection: the first alternative finds props and options typed `boolean`, the
   second positional flags; check whether the function or component branches on the
   flag near the top.
   Violation: a positional boolean parameter is the finding; no ESLint rule flags it,
   so it is review-only and routes to @refactoring — Split Flag Argument into two
   named functions when the branches share little, Introduce Parameter Object when
   the flag travels with other arguments (`send(alert, { dryRun: true })`). A named
   boolean stays when its two branches share their body and differ in one step. Boolean props are the component form: three or more on one
   component, or an `isLoading`/`isError`/`isEmpty` triplet, is the same finding —
   two components, or a `status`/`variant` union when the flags exclude each other.

5. **Inverse — is a NEW dispatch abstraction in the diff unearned?**
   Detect: judgment
   Detection: for each new interface with several implementations, class
   hierarchy, `Record` map or context introduced "for dispatch" in the diff, count
   production implementations/entries and the number of sites the old conditional
   occupied (`git log -p` or the pre-diff file).
   Violation: one switching site with trivial variance replaced by a hierarchy —
   score it (R1 scorecard); if LOW, the finding is the *extraction*, and the fix is
   Keep the Single Exhaustive Switch: one `switch` over the union, closed by
   `default: return assertNever(x)`. An interface whose second implementation
   exists only in tests is an R6 violation, not a dispatch win.
