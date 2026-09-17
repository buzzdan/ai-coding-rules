Real refactoring — a global configuration value, the message broker's address, was
read in 12 places deep in the codebase.

### Before — sideways access

```text
# messaging module
publishEvent(event):
    conn = broker.connect(env.Configs.BrokerAddress)   # global reached from a leaf
    ...

# the test must mutate shared state — and cannot run in parallel
testPublishEvent():
    env.Configs.BrokerAddress = "broker://test:4222"   # leaks into every other test
    ...
```

### After — dependency rejected upward, injected at the edge

```text
# messaging module
BrokerClient
    address                  # injected, not global
newBrokerClient(address):
    return BrokerClient(address)
BrokerClient.publishEvent(event):
    conn = broker.connect(self.address)
    ...

# api module — the global is read ONLY at the entry point
setupOrderHandler():
    client = newBrokerClient(env.Configs.BrokerAddress)
    orders = newOrderService(env.Configs.DBHost, client)
    return OrderHandler(orders)
```

The test constructs a client against a local test broker — no global writes, tests
run in parallel. The refactoring is incremental: one clean island at a time, pushing
the global up one level per iteration, from 20 scattered accesses down to 2 at the
entry points.
