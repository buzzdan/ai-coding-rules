Real production code, shown as its shape. `upsertInterfaceAddresses` must pick usable
IPv4/IPv6 addresses from a network interface and align config state with them.

### Before

```text
Config.upsertInterfaceAddresses(iface):
    addresses = iface.addresses()            # fails → return the failure with context
    ip4Added = false
    ip6Added = false
    for each a in addresses:
        if a is not a network address or not a.ip.isGlobalUnicast(): continue
        if a.ip is IPv6:                     # validate IP6
            if ip6Added: continue            # already added. skip
            if not self.parseIP6(a): fail "IP6 <ip> address is not valid"
            ip6Added = true
            continue
        if ip4Added: continue                # already added. skip
        if not self.parseIP4(a): fail "IP4 <ip> address is not valid"
        ip4Added = true
    if not ip4Added and not ip6Added: fail "IP address is not valid"
```

Forty-odd lines, cognitive complexity 18: type checks, boolean flags tracking loop
state, three nesting levels, `continue`-driven control flow — and the actual policy
(collect one IPv4 and one IPv6, then reconcile with config) is nowhere stated. The
comments `validate IP6` and `already added. skip` are naming blocks that want to be
functions. `parseIP4`/`parseIP6` mutate the config — the name hides the side effect.

### After

```text
Config.upsertInterfaceAddresses(iface):
    addresses = iface.addresses()            # fails → return the failure with context
    ipConfig = collectIPConfigFrom(addresses)
    self.alignIPs(ipConfig)                  # fails → return the failure with context
```

Read aloud: get addresses → collect them into an IPConfig → align config with what
was collected. Every line is the same altitude. The collection and validation logic
moved into an `IPConfig` leaf type that unit-tests with literals; the mutating
helpers were renamed `alignIPv4`/`alignIPv6` — "align" admits the side effect that
"parse" hid.
