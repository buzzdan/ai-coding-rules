```python
# CIDRPresence — a wrapper that adds NO value
@dataclass(frozen=True)
class CIDRPresence:
    value: bool

    def is_set(self) -> bool:
        return self.value  # just unwraps the bool!


CIDR_PRESENT = CIDRPresence(True)


@dataclass
class CIDRConfig:
    cluster_cidr: CIDRPresence  # wrapped bool
    service_cidr: CIDRPresence  # wrapped bool

    def are_both_set(self) -> bool:
        return self.cluster_cidr.is_set() and self.service_cidr.is_set()
```
