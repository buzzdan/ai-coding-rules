```python
def upsert_iface_addr_host(self, iface: Interface) -> None:
    """Set any IP from iface or raise if the provided IP does not match the interface."""
    ip_config = collect_ip_config_from(iface.addrs())
    self.align_ips(ip_config)


def collect_ip_config_from(addresses: Iterable[Addr]) -> IPConfig:
    ip_config = IPConfig()
    for a in addresses:
        ip_config.add_address(a)
    return ip_config
```
