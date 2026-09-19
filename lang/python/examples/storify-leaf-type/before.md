```python
def upsert_iface_addr_host(self, iface: Interface) -> None:
    """Set any IP from iface or raise if the provided IP does not match the interface."""
    addr_ip4_added = False
    addr_ip6_added = False
    for a in iface.addrs():
        ip = ipaddress.ip_address(a.address)
        if not ip.is_global:
            logger.debug("not a global unicast address: %s", a.address)
            continue
        if ip.version == 6:  # validate IP6
            if addr_ip6_added:  # already added. skip
                continue
            if not self._parse_ip6(ip):
                raise ValueError(f"IP6 {self.ip6!r} address is not valid")
            logger.debug("set IP6 %s", self.ip6)
            addr_ip6_added = True
            continue
        if addr_ip4_added:
            continue  # already added. skip
        if not self._parse_ip4(ip):
            raise ValueError(f"IP4 {self.ip4!r} address is not valid")
        logger.debug("set IP4 %s", self.ip6)
        addr_ip4_added = True

    if not addr_ip4_added and not addr_ip6_added:
        raise ValueError(f"IP address is not valid. IP4: {self.ip4!r}, IP6: {self.ip6!r}")


def _parse_ip4(self, ip: IPv4Address) -> bool:
    if self.ip4 == str(ip):
        return True
    if self.ip4 in (ANY_IPV4, ""):
        # use first ip found from interface
        self.ip4 = str(ip)
        return True
    return False


def _parse_ip6(self, ip: IPv6Address) -> bool:
    if self.ip6 == str(ip):
        return True
    if self.ip6 in (ANY_IPV6, ""):
        # use first ip found from interface
        self.ip6 = str(ip)
        return True
    return False
```
