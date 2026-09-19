# Dependency Rejection Case: Incremental Global Elimination

Demonstrates: R8

A real refactoring where a module-level `env.CONFIG` object reached from deep inside
the codebase (20+ access points) was eliminated incrementally — one clean island at a
time, pushing each global up one level per iteration until only the entry points
touched configuration. This is the case law for R8: the rejection move, why sideways
access resists testing, and the pragmatic stopping point.

This pattern differs from the other refactorings in one important way: it is **not a
one-time fix**. It is an incremental journey — start at the bottom (leaf code),
create one clean island at a time, push globals toward `main()` and the app
factory, and accept globals at the top.

## Which globals are the problem

Some globals are designed to be global and are fine: `logger =
logging.getLogger(__name__)`, constants and enums, exception classes, frozen
instances used as constants. The problem is configuration and mutable state reached
sideways:

- `env.CONFIG.nats_address`, `env.CONFIG.db_host`, `env.CONFIG.redis_url` — any
  `env.CONFIG.*` scattered through business logic, and any `os.environ` read outside
  the entry point.

Why these are defects: they make code untestable except by mutating shared state
(`monkeypatch` on a production module is the evidence), create hidden dependencies
invisible in any signature, forbid parallel tests, and weld every caller to one
config object.

## Before — global chaos

```python
# env.py — global config accessed everywhere
CONFIG = Config.from_environ()  # nats_address, db_host, redis_url


# ❌ messaging/publish.py — deep in the messaging code
def publish_event(event: Event) -> None:
    conn = nats.connect(env.CONFIG.nats_address)  # global reached from a leaf
    try:
        conn.publish(event.topic, json.dumps(event.payload).encode())
    finally:
        conn.close()


# ❌ order/service.py — more sideways access
def process_order(order_id: str) -> None:
    with connect_db(env.CONFIG.db_host) as db:
        ...
    publish_event(order_created_event)  # hides its NATS dependency
```

And the testing nightmare the globals cause:

```python
def test_publish_event(monkeypatch: pytest.MonkeyPatch) -> None:
    # ❌ must mutate shared state
    monkeypatch.setattr(env.CONFIG, "nats_address", "nats://test:4222")

    # ❌ cannot run in parallel — the global is shared
    # ❌ the patch is undone for this test only; anything cached from it leaks
    # ❌ testing two addresses means two patches of the same attribute
```

Inventory: `env.CONFIG.nats_address` in 12 locations, `env.CONFIG.db_host` in 8 —
20 sideways accesses, zero classes testable without a monkeypatch.

## Step 1 — map the dependency chain

```
main()
  └─ HTTP handlers (entry points)
       ├─ OrderService.process_order()      [USES env.CONFIG.db_host]
       │    └─ messaging.publish_event()    [USES env.CONFIG.nats_address]
       │    └─ messaging.publish_batch()    [USES env.CONFIG.nats_address]
       └─ UserService.create_user()
            └─ messaging.publish_event()    [USES env.CONFIG.nats_address]
```

The deepest usage — furthest from `main()` — is `messaging.publish_event`/
`publish_batch`. **Start there.** Bottom-up matters: extracting the leaf first means
each iteration produces a finished, testable island; top-down would thread
parameters through layers that still read globals underneath.

## Step 2 — create the first clean island

The rejection move: the function stops *fetching* the value and starts *being given*
it — as a constructor-injected field on a new type.

```python
# ✅ clean class with injected dependency
class NATSClient:
    def __init__(self, nats_address: str) -> None:
        self._nats_address = nats_address  # injected, not global

    def publish_event(self, event: Event) -> None:
        conn = nats.connect(self._nats_address)  # uses the injected value
        try:
            conn.publish(event.topic, json.dumps(event.payload).encode())
        finally:
            conn.close()
```

Island #1 is done: `NATSClient` is 100% testable with no globals in sight.

## Step 3 — push the global up one level

`messaging` no longer reads the global — its callers now face the dependency. Apply
the same move to them:

```python
# ✅ OrderService receives its dependencies
class OrderService:
    def __init__(self, db_host: str, nats_client: NATSClient) -> None:
        self._db_host = db_host  # injected
        self._nats_client = nats_client  # clean dependency

    def process_order(self, order_id: str) -> None:
        with connect_db(self._db_host) as db:
            ...
        self._nats_client.publish_event(order_created_event)
```

Island #2. The globals have moved up one level — they are now read by whoever
constructs `OrderService`.

## Step 4 — stop at the entry points

```python
# ✅ the config is read ONLY here, at wiring time
# api/wiring.py
def build_order_handler(config: Config) -> OrderHandler:
    nats_client = NATSClient(config.nats_address)
    order_service = OrderService(config.db_host, nats_client)
    return OrderHandler(order_service)


# app.py — the entry point owns the environment
def create_app() -> FastAPI:
    config = Config.from_environ()
    app = FastAPI()
    app.include_router(build_order_handler(config).router)
    return app
```

Final state: 1 environment read (in `create_app`), down from 20 sideways accesses.
`env.CONFIG` is deleted; everything below the handlers is constructor-injected.

## The test payoff

```python
def test_nats_client_publish_event(test_nats: RunningNATS) -> None:
    # ✅ a real NATS test server started by a fixture, fake data — no shared state
    client = messaging.NATSClient(test_nats.url)  # clean injection

    client.publish_event(TEST_EVENT)

    assert test_nats.received(TEST_EVENT.topic)


def test_nats_client_publish_event_connect_error() -> None:
    client = messaging.NATSClient("nats://nonexistent:4222")

    with pytest.raises(ConnectionError):
        client.publish_event(TEST_EVENT)
```

Contrast with the before-test: no `monkeypatch`, no ordering hazards, parallel by
default under `pytest-xdist`, and testing a second address is just constructing a
second client. The stand-in is a *real* NATS test server — a fake in the legitimate
sense (real implementation, fake data), not a `MagicMock` standing in for the
client.

Testability before: 0 classes testable without a monkeypatch, parallel tests
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
2. **The endpoint is pragmatic, not zero.** Configuration at `main()`, the app
   factory, and top-level wiring functions is acceptable — that is where it
   legitimately lives, read once from `os.environ`. Configuration in business logic,
   data access, and library code is not. The goal is globals only where wiring
   happens.
3. **Don't "fix" the globals that aren't broken.** `logging.getLogger(__name__)`,
   constants, enums, and exception classes stay. Spending iterations injecting a
   logger is ceremony, not rejection.
4. **Rejection pairs with self-validation.** Once dependencies arrive through
   constructors, the constructor is the natural place to validate them
   (`../rules/R2-self-validating-types.md`) — the island trusts its fields
   thereafter.
