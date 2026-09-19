Real refactoring shape — `CONFIG.nats_address` was read in 12 places deep in the
codebase.

### Before — sideways access

```python
# messaging/publish.py
from app.env import CONFIG                      # a module-level config object, built at import


def publish_event(event: Event) -> None:
    conn = nats.connect(CONFIG.nats_address)    # global reached from a leaf
    try:
        ...
    finally:
        conn.close()


# test_publish.py — the test must mutate shared state, and cannot run in parallel
def test_publish_event(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(env, "CONFIG", Config(nats_address="nats://test:4222"))   # leaks into every other test
    ...
```

### After — dependency rejected upward, injected at the edge

```python
# messaging/publish.py
class NatsClient:
    def __init__(self, nats_address: str) -> None:     # injected, not global
        self._nats_address = nats_address

    def publish_event(self, event: Event) -> None:
        conn = nats.connect(self._nats_address)
        ...


# app/__main__.py — the config is read ONLY at the entry point
def main() -> None:
    config = Config.from_environ()
    nats_client = NatsClient(config.nats_address)
    order_service = OrderService(config.db_host, nats_client)
    OrderHandler(order_service).serve()
```

The test constructs a client against a local fake NATS server — no module attribute
is written, tests run in parallel. The refactoring is incremental: one clean island
at a time, pushing the global up one level per iteration, from 20 scattered accesses
down to 2 at the entry point. Full worked case — the dependency map, the
island-by-island progression, and the test payoff:
`../examples/dependency-rejection.md`.

What stays at module level, in any module: `logger = logging.getLogger(__name__)`,
constants, enums, frozen instances used as constants, exception classes. What is
allowed only in the entry point: `Config.from_environ()`, `logging.basicConfig`, the
framework's `app` object, a registry filled by hand, `asyncio.run`.
