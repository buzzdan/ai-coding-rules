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
```

> **In Python:** absence is a declared `-> Port | None` that every caller narrows,
> checked by the type checker; `dict.get` beside `dict[k]` is the model. A `0`, `""` or
> `None` returned from a signature that promises `Port` is a sentinel and a finding, and
> `# ty: ignore[invalid-return-type]` (mypy: `# type: ignore[return-value]`) is its
> silenced form. Never a `tuple[Port, bool]`.
> `typing.NewType("PortNumber", int)` scores zero on the scorecard: it admits every
> literal.
