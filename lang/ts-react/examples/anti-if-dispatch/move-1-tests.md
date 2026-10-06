Each variant unit-tests as a leaf with literals — no `Alert` construction for the
pure methods, no switch-driving — and only the sender whose job is the network needs
an MSW handler:

```typescript
// slackSender.test.ts
it('accepts a channel-shaped recipient', () => {
  expect(slackSender.validate('#oncall')).toBe(true)
})

it('rejects a bare name', () => {
  expect(slackSender.validate('oncall')).toBe(false)
})

// channelSender.test.ts
it('rejects an unknown channel at the edge', () => {
  expect(() => parseChannel('carrier-pigeon')).toThrow(ApiError)
})

// webhookSender.test.ts — the only sender test that touches HTTP
it('posts the summary to the recipient URL', async () => {
  server.use(http.post(HOOK_URL, () => HttpResponse.json({})))
  const sent = webhookSender.send(anAlert({ recipient: HOOK_URL }))
  await expect(sent).resolves.toBeUndefined()
})
```

The drift bug (`webhook` missing from `validateChannel`) can no longer be written:
there is no second place to forget. There is no "every channel has a sender" test to
write either — `Record<Channel, ChannelSender>` is that test, and `tsc` runs it on
every `Channel` member.
