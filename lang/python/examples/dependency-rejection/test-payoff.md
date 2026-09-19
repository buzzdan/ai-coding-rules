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
