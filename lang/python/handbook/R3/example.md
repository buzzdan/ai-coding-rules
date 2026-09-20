```python
# ❌ flags track the loop, comments name the blocks, the policy is nowhere stated
def upsert_iface_addr_host(self, iface: Interface) -> None:
    ip4_added = False
    ip6_added = False
    for a in iface.addrs():
        if not isinstance(a, IPNetwork) or not a.ip.is_global:
            continue
        if a.ip.version == 6:  # validate IP6
            if ip6_added:  # already added. skip
                continue
            ...
        ...


# ✅ the story in three named steps; the loop moved onto a type that owns it
def upsert_iface_addr_host(self, iface: Interface) -> None:
    addrs = GlobalAddresses.from_interface(iface)
    self._align_ipv4(addrs.first_v4())
    self._align_ipv6(addrs.first_v6())
```

> **In Python:** a name reveals its side effect: `align_`/`upsert_`/`set_` mutate,
> `parse_`/`validate_`/`is_` never do. A `parse_ip4` that writes `self.ip4` is a
> storifying bug even when the flow reads well.
