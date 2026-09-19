```go
func TestPublishEvent(t *testing.T) {
    // ❌ must mutate shared state
    originalAddr := env.Configs.NATsAddress
    env.Configs.NATsAddress = "nats://test:4222"
    defer func() { env.Configs.NATsAddress = originalAddr }()

    // ❌ cannot run in parallel — the global is shared
    // ❌ state leaks between tests
    // ❌ testing two addresses means two mutations of the same variable
}
```

Inventory: `env.Configs.NATsAddress` in 12 locations, `env.Configs.DBHost` in 8 —
20 sideways accesses, zero types testable without global writes.
