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
