```python
# ❌ optional collaborator kept None-able; every method re-asks the question
class Reporter:
    def __init__(self, sink: Sink | None = None) -> None:
        self.sink = sink

    def record(self, ev: Event) -> None:
        if self.sink is not None:
            self.sink.write(ev)


# ✅ absence is a named value bound once; no argument is ever None
NULL_SINK = NullSink()          # a real Sink whose write() discards


class Reporter:
    def __init__(self, *, sink: Sink = NULL_SINK) -> None:
        self._sink = sink

    def record(self, ev: Event) -> None:
        self._sink.write(ev)    # no guard anywhere
```

> **In Python:** the self-validating type is the frozen dataclass with `__post_init__`
> shown under R1, or a `parse` classmethod that normalises then constructs. Public
> read-only fields are fine: a literal is not a hole because `__post_init__` runs on
> every construction. The finding is a mutable dataclass carrying invariants with no
> `__post_init__`. Where the repository already uses pydantic it is the boundary
> form, and `model_construct` and `model_copy(update=)` are its bypasses; a refactor
> never introduces pydantic. The fence above is the optional-collaborator case: a
> Null Object bound once as a module constant, never a `None` the methods guard.
