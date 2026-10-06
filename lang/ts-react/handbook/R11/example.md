```tsx
// ❌ the same discriminator in NotifyPanel.tsx, validateChannel.ts and alertsApi.ts
switch (alert.channel) {
  case 'email': return sendEmail(alert.recipient, renderEmail(alert))
  case 'slack': return postSlack(alert.recipient, renderSlack(alert))
  default: return Promise.reject(new Error(`unknown channel ${alert.channel}`))
}

// ✅ chosen once at the boundary; everything downstream tells
export type Channel = 'email' | 'slack' | 'webhook'

export interface ChannelSender {
  send(a: Alert): Promise<void>
  validate(recipient: string): boolean
  retryPolicy(): RetryPolicy
}

const CHANNEL_SENDERS: Record<Channel, ChannelSender> = { // complete, or it does not compile
  email: emailSender,
  slack: slackSender,
  webhook: webhookSender,
}

export function parseChannel(raw: string): ChannelSender { // the ONE place the raw string is inspected
  if (!isChannel(raw)) throw new ApiError(`unknown channel ${raw}`)
  return CHANNEL_SENDERS[raw]
}

// ✅ the one kept switch is closed by the compiler, not by an "unknown" arm
function channelIcon(channel: Channel): ReactNode {
  switch (channel) {
    case 'email': return <MailIcon />
    case 'slack': return <SlackIcon />
    case 'webhook': return <WebhookIcon />
    default: return assertNever(channel)
  }
}
```

> **In TypeScript:** the kept switch is over a discriminated union, closed by
> `default: return assertNever(x)` or `satisfies never`; that arm is the completeness
> proof `tsc` checks, not an unknown-kind default, and a `default: return null` in a
> render switch is the finding. Prefer a `Record<Kind, …>` of handlers or components
> first, a strategy object second, a class hierarchy last. Boolean props:
> `isLoading`/`isError`/`isEmpty` triplets become a status union, and three or more
> boolean props on one component is a Split Flag Argument candidate (T3).
