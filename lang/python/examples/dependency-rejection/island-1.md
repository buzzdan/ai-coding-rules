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
