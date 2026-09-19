```go
func TestNATSClient_PublishEvent(t *testing.T) {
    t.Parallel() // ✅ possible now — no shared state

    testNATS := startTestNATS(t) // real NATS test server, fake data
    defer testNATS.Stop()

    client := messaging.NewNATSClient(testNATS.URL()) // clean injection

    err := client.PublishEvent(testEvent)
    require.NoError(t, err)
}

func TestNATSClient_PublishEvent_ConnectError(t *testing.T) {
    t.Parallel()

    client := messaging.NewNATSClient("nats://nonexistent:4222")

    err := client.PublishEvent(testEvent)
    assert.Error(t, err)
}
```

Contrast with the before-test: no save/mutate/restore dance, no ordering hazards,
parallel by default, and testing a second address is just constructing a second
client. The stand-in is a *real* NATS test server — a fake in the legitimate sense
(real implementation, fake data), not an interface-injected double.

Testability before: 0 types testable without global mutation, parallel tests
impossible. After: 3 clean islands (`NATSClient`, `OrderService`, `UserService`),
100% coverage on them, fully parallel.
