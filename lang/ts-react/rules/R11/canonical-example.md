A notifier must deliver alerts over email, Slack, or a webhook. The channel is decided
by a string field, and three parts of the codebase ask which one it is.

### Before

```tsx
// ❌ src/pages/Alerts/NotifyPanel.tsx — first copy of the discriminator
function NotifyPanel({ alert }: Readonly<{ alert: Alert }>) {
  switch (alert.channel) {
    case 'email':
      return <EmailForm recipient={alert.recipient} />
    case 'slack':
      return <SlackForm recipient={alert.recipient} />
    case 'webhook':
      return <WebhookForm recipient={alert.recipient} />
    default:
      return null                                   // "unknown channel" rendered as nothing
  }
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
finding all three (and the fourth one hiding in a test helper). The render switch also
carries the `default: return null` path — the "maybe-unknown channel" concept leaks
into a component, the behavioural twin of R1's maybe-invalid port.

### After

```tsx
// Channel is the behaviour, not a string. Each variant is a leaf object.
export type Channel = 'email' | 'slack' | 'webhook'

export interface ChannelSender {
  readonly Form: ComponentType<{ readonly recipient: string }>
  readonly retryPolicy: RetryPolicy
  validRecipient(recipient: string): boolean
}

const SLACK: ChannelSender = {
  Form: SlackForm,
  retryPolicy: { attempts: 3, baseDelayMs: 5_000 },
  validRecipient: (recipient) => recipient.startsWith('#'),
}

// The ONLY place the raw string is inspected — the decision is made once, at the
// boundary, like R2's parsePort. The Record is complete or it does not compile.
const CHANNELS: Record<Channel, ChannelSender> = {
  email: EMAIL,
  slack: SLACK,
  webhook: WEBHOOK,
}

export function parseChannel(raw: string): ChannelSender {
  if (!isChannel(raw)) throw new ApiError(`unknown channel ${raw}`)   // thrown at the edge, nowhere else
  return CHANNELS[raw]
}

function NotifyPanel({ alert }: Readonly<{ alert: Alert }>) {
  return <alert.channel.Form recipient={alert.recipient} />
}
```

The three switches are gone — call sites read `alert.channel.validRecipient(…)`,
`alert.channel.retryPolicy`, `<alert.channel.Form />`. There is no `default: return
null` anywhere downstream: an `Alert` that exists holds a `ChannelSender` that
exists, so "unknown channel" is unrepresentable past the boundary. Adding SMS is one
new object plus one entry in `CHANNELS` — existing modules untouched, `tsc` refusing
to build until the entry exists, and each channel's behaviour unit-tests as a leaf
with literals. Where one switch legitimately stays — a single site over a closed
union — it is a `switch` whose `default` arm is `return assertNever(channel)`, so
`tsc` fails the build when a variant is added but not handled; that arm is the
completeness proof, not an "unknown kind" default. The component form of the flag
argument is the boolean prop: `<Panel isCompact isInline showHeader />` is three
switches the caller sets and the component unpicks — Split Flag Argument into two
components, or one `variant: 'compact' | 'inline' | 'full'` union when the flags
exclude each other. Full worked study including the strategy-map variant and the
rejection counter-case: `../examples/anti-if-dispatch.md`.
