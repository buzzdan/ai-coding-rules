Some globals are designed to be global and are fine: loggers (`slog`, `zerolog`),
constants and enums, `var Err... = errors.New` sentinels. The problem is
configuration and mutable state reached sideways:

- `env.Configs.NATsAddress`, `env.Configs.DBHost`, `env.Configs.RedisURL` — any
  `env.Configs.*` scattered through business logic.

Why these are defects: they make code untestable except by mutating shared state,
create hidden dependencies invisible in any signature, forbid parallel tests, and
weld every caller to one config struct.
