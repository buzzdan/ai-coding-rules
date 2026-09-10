# Dependency Rejection Case: Incremental Global Elimination

Demonstrates: R8

A real refactoring where `env.Configs.*` globals reached from deep inside the
codebase (20+ access points) were eliminated incrementally — one clean island at a
time, pushing each global up one level per iteration until only the entry points
touched configuration. This is the case law for R8: the rejection move, why sideways
access resists testing, and the pragmatic stopping point.

This pattern differs from the other refactorings in one important way: it is **not a
one-time fix**. It is an incremental journey — start at the bottom (leaf code),
create one clean island at a time, push globals toward `main()`, and accept globals
at the top.

## Which globals are the problem

Some globals are designed to be global and are fine: loggers (`slog`, `zerolog`),
constants and enums, `var Err... = errors.New` sentinels. The problem is
configuration and mutable state reached sideways:

- `env.Configs.NATsAddress`, `env.Configs.DBHost`, `env.Configs.RedisURL` — any
  `env.Configs.*` scattered through business logic.

Why these are defects: they make code untestable except by mutating shared state,
create hidden dependencies invisible in any signature, forbid parallel tests, and
weld every caller to one config struct.

## Before — global chaos

```go
// Global config accessed everywhere
package env

var Configs struct {
    NATsAddress string
    DBHost      string
    RedisURL    string
}

// ❌ deep in the messaging code
package messaging

func PublishEvent(event Event) error {
    conn, err := nats.Connect(env.Configs.NATsAddress) // global reached from a leaf
    if err != nil {
        return fmt.Errorf("connect failed: %w", err)
    }
    defer conn.Close()

    data, err := json.Marshal(event)
    if err != nil {
        return err
    }
    return conn.Publish(event.Topic, data)
}

// ❌ in the order service — more sideways access
package order

func ProcessOrder(orderID string) error {
    db := connectDB(env.Configs.DBHost)
    defer db.Close()

    return messaging.PublishEvent(orderCreatedEvent) // hides its NATS dependency
}
```

And the testing nightmare the globals cause:

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

## Step 1 — map the dependency chain

```
main()
  └─ HTTP handlers (entry points)
       ├─ OrderService.ProcessOrder()      [USES env.Configs.DBHost]
       │    └─ messaging.PublishEvent()    [USES env.Configs.NATsAddress]
       │    └─ messaging.PublishBatch()    [USES env.Configs.NATsAddress]
       └─ UserService.CreateUser()
            └─ messaging.PublishEvent()    [USES env.Configs.NATsAddress]
```

The deepest usage — furthest from `main()` — is `messaging.PublishEvent`/
`PublishBatch`. **Start there.** Bottom-up matters: extracting the leaf first means
each iteration produces a finished, testable island; top-down would thread
parameters through layers that still read globals underneath.

## Step 2 — create the first clean island

The rejection move: the function stops *fetching* the value and starts *being given*
it — as a constructor-injected field on a new type.

```go
// ✅ clean type with injected dependency
type NATSClient struct {
    natsAddress string // injected, not global
}

func NewNATSClient(natsAddress string) *NATSClient {
    return &NATSClient{natsAddress: natsAddress}
}

func (c *NATSClient) PublishEvent(event Event) error {
    conn, err := nats.Connect(c.natsAddress) // uses the injected value
    if err != nil {
        return fmt.Errorf("connect failed: %w", err)
    }
    defer conn.Close()

    data, err := json.Marshal(event)
    if err != nil {
        return err
    }
    return conn.Publish(event.Topic, data)
}
```

Island #1 is done: `NATSClient` is 100% testable with no globals in sight.

## Step 3 — push the global up one level

`messaging` no longer reads the global — its callers now face the dependency. Apply
the same move to them:

```go
// ✅ OrderService receives its dependencies
package order

type OrderService struct {
    dbHost     string       // injected
    natsClient *NATSClient  // clean dependency
}

func NewOrderService(dbHost string, natsClient *NATSClient) *OrderService {
    return &OrderService{dbHost: dbHost, natsClient: natsClient}
}

func (s *OrderService) ProcessOrder(orderID string) error {
    db := connectDB(s.dbHost)
    defer db.Close()

    return s.natsClient.PublishEvent(orderCreatedEvent)
}
```

Island #2. The globals have moved up one level — they are now read by whoever
constructs `OrderService`.

## Step 4 — stop at the entry points

```go
// ✅ the global is read ONLY here, at wiring time
package api

type OrderHandler struct {
    orderService *OrderService
}

func SetupOrderHandler() *OrderHandler {
    natsClient := NewNATSClient(env.Configs.NATsAddress)
    orderService := NewOrderService(env.Configs.DBHost, natsClient)
    return &OrderHandler{orderService: orderService}
}

func (h *OrderHandler) HandleCreateOrder(w http.ResponseWriter, r *http.Request) {
    err := h.orderService.ProcessOrder(orderID) // all clean code from here down
    // ...
}
```

Final state: 2 global accesses (both in setup functions), down from 20. Everything
below the handlers is constructor-injected.

## The test payoff

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

## Why sideways access resists testing

A global read is an input the test cannot supply through the code's own surface. To
control it, the test must write the shared variable — which serializes the whole
test binary around that variable, leaks values into unrelated tests, and still only
supports one value at a time. Constructor injection turns the same input into an
argument: each test builds its own instance, values never collide, and the
dependency is visible in the signature where reviewers and callers can see it.

## The incremental progression

```
Iteration 1: extract NATSClient        — global accesses 20 → 14, islands: 1
Iteration 2: extract OrderService      — global accesses 14 → 8,  islands: 2
Iteration 3: extract UserService       — global accesses 8 → 4,   islands: 3
Iteration 4: push to handler setup     — global accesses 4 → 2    ✅ done
```

Every iteration is a working, tested, deployable state. No big-bang refactoring —
if the work stops after iteration 2, the codebase is still strictly better than it
started.

## The decision points

1. **Bottom-up, not top-down.** Start at the deepest usage; each extraction is
   complete on its own. Top-down threading leaves half-injected layers that read
   globals underneath the new parameters.
2. **The endpoint is pragmatic, not zero.** Globals at `main()`, handler setup, and
   top-level factories are acceptable — that is where configuration legitimately
   lives. Globals in business logic, data access, and library code are not. The goal
   is globals only where wiring happens.
3. **Don't "fix" the globals that aren't broken.** Loggers designed for global use,
   constants, and error sentinels stay. Spending iterations wrapping `slog` is
   ceremony, not rejection.
4. **Rejection pairs with self-validation.** Once dependencies arrive through
   constructors, the constructor is the natural place to validate them
   (`../rules/R2-self-validating-types.md`) — the island trusts its fields
   thereafter.
