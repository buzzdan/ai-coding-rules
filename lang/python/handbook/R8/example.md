```python
# ❌ a module-level config built at import, reached from a leaf
from app.env import CONFIG

def publish_event(event: Event) -> None:
    conn = connect(CONFIG.nats_address)


# ✅ read once in the entry point, pushed down as a value
class NatsClient:
    def __init__(self, nats_address: str) -> None:
        self._nats_address = nats_address

def main() -> None:
    config = Config.from_environ()
    OrderHandler(OrderService(config.db_host, NatsClient(config.nats_address))).serve()
```

> **In Python:** silent everywhere: `logger = logging.getLogger(__name__)`,
> constants, enums, frozen instances as constants, exception classes. Silent only in
> the entry point: `Config.from_environ()`, `logging.basicConfig`, the framework
> `app`, a registry filled by hand, `asyncio.run`. Reported elsewhere: `os.environ`
> reads, a module-level container functions write into, `asyncio.run` or
> `get_event_loop` in library code. A test that monkeypatches production
> configuration is evidence against the production code, not a fix for the test.
