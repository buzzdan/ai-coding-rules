```python
# ❌ the rule lives at the call site, twice, and 0 means "none"
def management_port(self) -> int:
    for p in self.spec.ports:
        if p.name == "weka-api" and 0 < p.port <= 65535:
            return p.port
    for p in self.spec.ports:
        if 0 < p.port <= 65535:
            return p.port
    return 0


# ✅ a Port cannot exist out of range; "first valid" collapses to "first"
@dataclass(frozen=True, slots=True)
class Port:
    name: str
    number: int

    def __post_init__(self) -> None:
        if not 0 < self.number <= 65535:
            raise ValueError(f"port {self.name!r}: {self.number} out of range 1-65535")


class Ports:
    def first_named(self, name: str) -> Port | None: ...
    def first(self) -> Port | None: ...


# ❌ a shape crosses the boundary; the caller pokes the method out of it
def bearer_token(headers: dict[str, str]) -> str | None:
    for name, value in headers.items():
        if name == "Authorization" and value.startswith("Bearer "):
            return value.removeprefix("Bearer ")
    return None


# ✅ the container has a name, and the loop is its method
class Headers:
    def __init__(self, raw: Mapping[str, str]) -> None:
        self._raw = dict(raw)

    def auth_token(self) -> str | None:
        value = self._raw.get("Authorization")
        if value is None or not value.startswith("Bearer "):
            return None
        return value.removeprefix("Bearer ")
```

> **In Python:** absence is a declared `-> Port | None` that every caller narrows,
> checked by the type checker; `dict.get` beside `dict[k]` is the model. A `0`, `""` or
> `None` returned from a signature that promises `Port` is a sentinel and a finding, and
> `# ty: ignore[invalid-return-type]` (mypy: `# type: ignore[return-value]`) is its
> silenced form. Never a `tuple[Port, bool]`.
> `typing.NewType("PortNumber", int)` scores zero on the scorecard: it admits every
> literal. A `dict[str, str]` or `tuple[str, str]` returned from a function is a shape,
> not a concept: read what the receivers do with it, and name the type. A nested
> annotation (`tuple[dict[object, object], str]`, `dict[str, list[str]]`) is always a
> missing `NamedTuple` or frozen dataclass; `tuple[X, ...]` is one level, not nesting.
