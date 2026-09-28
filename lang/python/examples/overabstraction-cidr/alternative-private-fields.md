When the need is controlled mutation rather than validation or logic, Python's
spelling of private fields with read-only accessors is a frozen dataclass: every
field is readable, none is assignable after construction, and only the parser
builds one:

```python
@dataclass(frozen=True)
class CIDRConfig:
    """Which CIDR configurations are present. Built only by parse_cidr_config."""

    cluster_cidr_set: bool
    service_cidr_set: bool

    def are_both_set(self) -> bool:
        return self.cluster_cidr_set and self.service_cidr_set


def parse_cidr_config(args: Sequence[str]) -> CIDRConfig:
    ...  # the one place the flags are decided
```

Why this beat the wrapper:

- **Same safety** — `frozen=True` makes `config.cluster_cidr_set = True` raise
  `FrozenInstanceError` at run time and fail ty before it; only the parser decides
  the values.
- **4 fewer lines** than the `CIDRPresence` approach, and one class instead of two.
- **Same readability** — `config.cluster_cidr_set` is just as clear as
  `config.cluster_cidr.is_set()`.
- **No wrapper ceremony** — the fields are what they are: bools.
