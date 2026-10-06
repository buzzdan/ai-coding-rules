```tsx
// src/services/natsClient.test.ts
it('publishes the event over the socket', async () => {
  const socket = new FakeSocket() // ✅ a fake at the transport boundary, fake data — no shared state
  const client = new NATSClient(socket, { url: 'wss://nats.test', token: 'test-token' }) // clean injection
  await client.publishEvent(TEST_EVENT)
  expect(socket.published).toEqual([{ subject: TEST_EVENT.topic, data: JSON.stringify(TEST_EVENT.payload) }])
})

it('rejects when the socket refuses the connection', async () => {
  const client = new NATSClient(FakeSocket.refusing(), { url: 'wss://nonexistent:4222', token: 'test-token' })
  await expect(client.publishEvent(TEST_EVENT)).rejects.toThrow(ConnectionError)
})

// src/pages/Orders/OrdersPage.test.tsx — a page test supplies its own services
it('processes the selected order', async () => {
  const orders = new OrderService(new NATSClient(new FakeSocket(), TEST_NATS), 'https://api.test')
  const { user } = renderWithProviders(<OrdersPage />, { services: { ...TEST_SERVICES, orders } })
  await user.click(screen.getByRole('button', { name: 'Process' }))
  expect(await screen.findByText('Order processed')).toBeInTheDocument()
})
```

Contrast with the before-test: no `vi.mock`, no `vi.stubEnv`, no write to the shared
`window`, no ordering hazards, parallel by default under Vitest, and testing a second
URL is just constructing a second client. The stand-in is a `FakeSocket` at the
transport boundary — a fake in the legitimate sense (speaks the socket's contract,
records what it was given), not a `vi.mock` of the client module; the page test does
the same one level up, handing `ServicesProvider` its own services while MSW answers
the HTTP.

Testability before: 0 modules testable without a `vi.mock` or a `window` write,
parallel tests impossible. After: 3 clean islands (`NATSClient`, `OrderService`,
`UserService`), 100% coverage on them, fully parallel.
