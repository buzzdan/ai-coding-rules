Define the interface from the union of what the copies do: `NotifyPanel` switches on
delivery, `validateChannel` on addressing, `retryPolicyFor` on retry policy — three
methods, one object per variant:

```typescript
// alerts/channelSender.ts
export interface ChannelSender {
  send(a: Alert): Promise<void>
  validate(recipient: string): boolean
  retryPolicy(): RetryPolicy
}

export type Channel = 'email' | 'slack' | 'webhook'

// The single decision point. This lookup is ALLOWED — it is the one place the raw
// string may be inspected (R11), exactly as a parseX factory is the one place a raw
// value is validated (R2). The Record is complete by construction: tsc rejects a
// missing key.
const CHANNEL_SENDERS: Record<Channel, ChannelSender> = {
  email: emailSender,
  slack: slackSender,
  webhook: webhookSender,
}

function isChannel(name: string): name is Channel {
  return Object.hasOwn(CHANNEL_SENDERS, name)
}

export function parseChannel(name: string): ChannelSender {
  if (!isChannel(name)) {
    throw new ApiError(`unknown channel ${name}`) // at the edge, nowhere else
  }
  return CHANNEL_SENDERS[name]
}
```

```typescript
// alerts/slackSender.ts — each variant is a leaf object owning ALL its behavior
export const slackSender: ChannelSender = {
  send(a) {
    return postSlack(a.recipient, renderSlack(a))
  },
  validate(recipient) {
    return recipient.startsWith('#')
  },
  retryPolicy() {
    return { attempts: 3, delayMs: 5_000 }
  },
}
```

`Alert` now holds a `ChannelSender`, constructed at the boundary (`parseAlert` in the
alerts API module calls `parseChannel` and fails fast there, before the value reaches
the query cache). The three switching sites collapse to method calls:

```tsx
export function NotifyPanel({ alert }: Readonly<{ alert: Alert }>) {
  return <SendButton onSend={() => alert.channel.send(alert)} />
}

export function validateChannel(a: Alert): boolean {
  return a.channel.validate(a.recipient)
}

export function retryPolicyFor(a: Alert): RetryPolicy {
  return a.channel.retryPolicy()
}
```

(And once they are one-liners, the wrappers themselves usually dissolve into their
callers — the story functions call the methods directly, R3.)

What was deleted, not relocated: every `default:` arm and every `??` default
downstream. An `Alert` that exists holds a `ChannelSender` that exists; "unknown
channel" is unrepresentable past `parseChannel`. Adding SMS is now one new module
(`smsSender.ts`), one `Channel` member and one `CHANNEL_SENDERS` entry — `tsc`
demands the entry the moment the member exists — and no other module changes.
