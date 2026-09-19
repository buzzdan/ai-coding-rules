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
