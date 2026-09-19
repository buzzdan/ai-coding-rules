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
