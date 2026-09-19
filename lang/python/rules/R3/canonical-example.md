Production-shaped code. `upsert_iface_addr_host` must pick usable IPv4 and IPv6
addresses from a network interface and align config state with them.

### Before

```python
def upsert_iface_addr_host(self, iface: Interface) -> None:
    try:
        addrs = iface.addrs()
    except OSError as err:
        raise ConfigError(f"network addr: {err}") from err
    ip4_added = False
    ip6_added = False
    for a in addrs:
        if not isinstance(a, IPNetwork) or not a.ip.is_global:
            continue
        if a.ip.version == 6:  # validate IP6
            if ip6_added:  # already added. skip
                continue
            if not self.parse_ip6(a):
                raise ConfigError(f"IP6 {self.ip6!r} address is not valid")
            ip6_added = True
            continue
        if ip4_added:
            continue  # already added. skip
        if not self.parse_ip4(a):
            raise ConfigError(f"IP4 {self.ip4!r} address is not valid")
        ip4_added = True
    if not ip4_added and not ip6_added:
        raise ConfigError(f"IP address is not valid. IP4: {self.ip4!r}, IP6: {self.ip6!r}")
```

Twenty-four lines, cognitive complexity 18: an `isinstance` test, boolean flags
tracking loop state, three nesting levels, `continue`-driven control flow — and the
actual policy (collect one IPv4 and one IPv6, then reconcile with config) is nowhere
stated. The comments `# validate IP6` and `# already added. skip` are naming blocks
that want to be functions. `parse_ip4`/`parse_ip6` mutate `self` — the name hides
the side effect.

### After

```python
def upsert_iface_addr_host(self, iface: Interface) -> None:
    try:
        addrs = iface.addrs()
    except OSError as err:
        raise ConfigError(f"network addr: {err}") from err

    ip_config = IPConfig.collect(addrs)

    self.align_ips(ip_config)
```

Read aloud: get addresses → collect them into an IPConfig → align config with what
was collected. Every line is the same altitude. The collection and validation logic
moved into an `IPConfig` leaf type that unit-tests with literals; its `collect`
classmethod is a comprehension over the global addresses, first IPv4 and first IPv6
picked with `next(...)`, so the two boolean flags have no reason to exist. The
mutating helpers were renamed `align_ipv4`/`align_ipv6` — "align" admits the side
effect that "parse" hid. Full worked study, including the leaf type and the test
payoff: `../examples/storify-leaf-type.md`.
