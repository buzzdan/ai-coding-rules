```python
@dataclass
class CIDRConfig:
    cluster_cidr_set: bool
    service_cidr_set: bool
```

`config.cluster_cidr_set` reads exactly as well as `config.cluster_cidr.is_set()`, at
zero ceremony. Acceptable when mutation discipline isn't a concern (small, disciplined
surface; short-lived value).
