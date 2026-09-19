```python
@dataclass
class IPConfig:
    """The first usable global-unicast IPv4 and IPv6 address of an interface."""

    ip4: str = ""
    ip6: str = ""

    def add_address(self, a: Addr) -> None:
        ip = ipaddress.ip_address(a.address)
        if not ip.is_global:
            logger.debug("not a global unicast address: %s", a.address)
            return

        if ip.version == 4:
            if self.ip4:
                return  # already added
            self.ip4 = str(ip)
            return

        if self.ip6:
            return  # already added
        self.ip6 = str(ip)

    def validate(self) -> None:
        if not self.ip4 and not self.ip6:
            raise ValueError("IP addresses are not found")
```

The boolean flags are gone: "already added" is now a question the collected state
answers (`if self.ip4:`), and the `continue`s became early `return`s — each address
is handled by one small decision tree instead of steering a shared loop.
