**In Python:** a `NullSink` whose `write()` discards, bound once as a module-level
constant `NULL_SINK = NullSink()` (a name, not a call — ruff `B008` flags a call in
a default), and a clock that is `SYSTEM_CLOCK = SystemClock()` the same way; the
parameter is keyword-only and typed `Sink`, never `Sink | None`, so
`Reporter(sink=None)` fails mypy before it runs and `__init__` raises `TypeError`
for the caller mypy never saw. A `sink: Sink | None = None` default replaced inside
`__init__` is allowed only when the default is genuinely mutable or expensive to
build; the attribute is then still typed `Sink` and no method guards it.
