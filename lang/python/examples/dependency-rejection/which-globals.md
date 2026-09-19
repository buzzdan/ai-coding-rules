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
