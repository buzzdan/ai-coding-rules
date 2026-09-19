```python
def align_ips(self, ip_config: IPConfig) -> None:
    ip_config.validate()
    self._align_ipv4(ip_config.ip4)
    self._align_ipv6(ip_config.ip6)


def _align_ipv4(self, ip: str) -> None:
    if self.ipv4 == ip:
        return  # matches interface
    if self.ipv4 in (ANY_IPV4, ""):
        self.ipv4 = ip  # use first ip found from interface
        return
    raise ValueError(f"existing IPv4 [{ip}] mismatch configured [{self.ipv4}]")


def _align_ipv6(self, ip: str) -> None:
    if self.ipv6 == ip:
        return
    if self.ipv6 in (ANY_IPV6, ""):
        self.ipv6 = ip
        return
    raise ValueError(f"existing IPv6 [{ip}] mismatch configured [{self.ipv6}]")
```

`_parse_ip4` → `_align_ipv4`: "align" admits the mutation that "parse" hid, and the
boolean returns became exceptions that say *what* mismatched.
