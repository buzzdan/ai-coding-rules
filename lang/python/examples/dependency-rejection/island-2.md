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
