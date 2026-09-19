The Port case, in Python. A service wraps a Kubernetes Service description and must
pick the management port: prefer the port named `weka-api`, else fall back to the
first valid port.

### Before

```python
def management_port(self) -> int:
    for p in self.spec.ports:
        if p.name == "weka-api" and 0 < p.port <= 65535:
            return p.port
    for p in self.spec.ports:
        if 0 < p.port <= 65535:
            return p.port
    return 0
```

Four defects in nine lines:

- The validity rule `0 < p.port <= 65535` is duplicated across the two loops — two
  copies that can drift independently.
- Two abstractions exist only as unnamed boolean expressions: "valid port" and
  "named management port".
- The logic lives on the wire DTO, so it is testable only by constructing the whole
  service object around a Kubernetes fixture.
- `return 0` is a sentinel: validity is encoded in-band, and every caller must know
  that `0` means "none".

### Stage 1 — self-validating types with constructors

```python
@dataclass(frozen=True)
class ServicePort:
    """The wire DTO: public fields, no rules, exactly what the API returned."""

    name: str
    port: int


@dataclass(frozen=True, slots=True)
class Port:
    """A named, validated service port; it cannot exist out of range."""

    name: str
    number: int

    def __post_init__(self) -> None:
        if not 0 < self.number <= 65535:
            raise ValueError(f"port {self.name!r}: {self.number} out of range 1-65535")


@dataclass(frozen=True, slots=True)
class Ports:
    """A collection of valid ports."""

    _items: tuple[Port, ...]

    @classmethod
    def parse(cls, wire: Iterable[ServicePort]) -> "Ports":
        # Drops invalid wire entries — a documented decision that mirrors the
        # original skip-and-fall-back behaviour: an invalid port was never chosen
        # before; now it never exists.
        items = []
        for w in wire:
            try:
                items.append(Port(w.name, w.port))
            except ValueError:
                continue
        return cls(tuple(items))

    def first_named(self, name: str) -> Port | None:
        return next((p for p in self._items if p.name == name), None)

    def first(self) -> Port | None:
        return self._items[0] if self._items else None

    def management(self) -> Port | None:
        # Stage 2 relocates this method — the "weka-api" preference is feature
        # policy, not networking vocabulary.
        return self.first_named("weka-api") or self.first()
```

The payoff, stated plainly: notice what was **not** written. There is no `is_valid()`
method and no validity loop anywhere. Self-validation does not move the
`0 < number <= 65535` check somewhere tidier — it **deletes the concept of a
maybe-invalid port from downstream logic**. Every `Port` inside a `Ports` is valid by
construction (`__post_init__` runs on every literal, so there is no path around it),
so "find the first valid port" collapses to "find the first port". And
`management()` returns `Port | None`, a declared absence — never a `0` sentinel that
smuggles validity back in-band. Absence that is exceptional would raise instead;
the Python rule is that `None` is a declared absence and never a disguised failure
(`R2-self-validating-types.md`).

### Stage 2 — placement (R4 rung 3)

`Port`, `Ports`, `first_named`, `first` say nothing about Kubernetes or Weka — they
are generic networking vocabulary, so they move to a shared `networking` package
(rung 3 of `R4-helper-placement.md`). The wire adapter `Ports.parse` knows the
Kubernetes DTO, so it stays with the feature. The feature policy stays home as a
two-line storified method:

```python
def management_port(self) -> networking.Port | None:
    return self.ports.first_named(WEKA_API_PORT) or self.ports.first()
```

Teaching point: **promote only the domain-generic parts.** The `WEKA_API_PORT`
constant is feature policy and stays in the feature — a shared package that knows
one feature's port names is not shared vocabulary, it is leaked policy.

### Stage 3 — testing contrast

Before, exercising `management_port()` meant constructing the service around a full
Kubernetes fixture — building a cluster object to check a range predicate. After,
the logic is a leaf and its rung-0 unit tests (the composition ladder's bottom rung —
see @testing) are tuple literals against `networking.Ports`; no big-object
construction:

```python
def test_first_named_prefers_the_named_port() -> None:
    api = Port("weka-api", 14000)
    web = Port("http", 80)

    assert Ports((web, api)).first_named("weka-api") == api


def test_port_rejects_out_of_range() -> None:
    with pytest.raises(ValueError, match="out of range"):
        Port("weka-api", 70000)
```

### The opposite failure: don't over-extract

```python
# ❌ Ceremony, not a type: no rule, no behaviour — every int is as valid as any other.
ReplicaCount = NewType("ReplicaCount", int)


class Name(str):  # ❌ the only "method" unwraps
    def as_str(self) -> str:
        return str(self)
```

Score it against the scorecard below: no validation (+0), no meaningful methods (+0),
one call site (+0) → Score 0. Keep the `int`; if you want a name, a well-named
variable or a private helper in the same module is the whole answer
(`R4-helper-placement.md`, rung 1). `NewType` is erased at run time and admits every
literal, so it earns nothing on the invariant line either. Deep worked rejection
with the cheaper alternatives: `../examples/overabstraction-cidr.md`.
