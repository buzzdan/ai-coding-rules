The alert feature delivers over email, Slack, or a webhook. `Alert.channel` is a
`string` straight off the wire (already an R1 smell), and three sites ask what it is:

```tsx
// ❌ alerts/NotifyPanel.tsx
export function NotifyPanel({ alert }: Readonly<{ alert: Alert }>) {
  const send = (): Promise<void> => {
    switch (alert.channel) {
      case 'email':
        return sendEmail(alert.recipient, renderEmail(alert))
      case 'slack':
        return postSlack(alert.recipient, renderSlack(alert))
      case 'webhook':
        return postJson(alert.recipient, alert.summary)
      default:
        return Promise.reject(new Error(`unknown channel ${alert.channel}`))
    }
  }
  return <SendButton onSend={send} />
}

// ❌ alerts/validateChannel.ts — drifted: webhook was never added here
export function validateChannel(a: Alert): boolean {
  if (a.channel === 'email') {
    return a.recipient.includes('@')
  }
  if (a.channel === 'slack') {
    return a.recipient.startsWith('#')
  }
  return false
}

// ❌ alerts/retryPolicy.ts — the same decision wearing an object lookup with a default
const RETRY_POLICIES: Record<string, RetryPolicy> = {
  webhook: { attempts: 5, baseDelayMs: 0 },
  slack: { attempts: 3, baseDelayMs: 5_000 },
}

export function retryPolicyFor(a: Alert): RetryPolicy {
  return RETRY_POLICIES[a.channel] ?? { attempts: 1, baseDelayMs: 60_000 }
}
```
