  **The Python shape.** A do-nothing object is stateless, so it can be a real default
  value: `NULL_SINK = NullSink()` at module level (a name, not a call — ruff's `B008`
  flags a call in a default), the parameter keyword-only and typed `Sink`, never
  `Sink | None`. mypy then rejects `Reporter(sink=None)` before it runs, and the
  constructor rejects it at run time for callers mypy never saw. `sink: Sink | None =
  None` with `self._sink = sink or NullSink()` inside the constructor keeps `None`
  legal and merely moves the check; it is allowed only when the default is genuinely
  mutable or expensive to build, and even then the attribute is typed without `None`
  and no method guards it.

  ```python
  # ❌ optional sink kept None-able; every method re-asks the question
  class Reporter:
      def __init__(self, sink: Sink | None = None) -> None:
          self.sink = sink

      def record(self, ev: Event) -> None:
          if self.sink is not None:
              self.sink.write(ev)


  # ✅ absence is a named value; no argument is ever None
  NULL_SINK = NullSink()          # a real Sink whose write() discards
  SYSTEM_CLOCK = SystemClock()


  class Reporter:
      def __init__(self, *, sink: Sink = NULL_SINK, clock: Clock = SYSTEM_CLOCK) -> None:
          if sink is None or clock is None:      # reachable only from untyped callers
              raise TypeError("Reporter: pass NULL_SINK or SYSTEM_CLOCK, never None")
          self._sink = sink
          self._clock = clock

      def record(self, ev: Event) -> None:
          self._sink.write(ev)                   # no guard anywhere
  # production: Reporter(sink=FileSink(path)); tests: Reporter(clock=FixedClock(t0))
  ```
