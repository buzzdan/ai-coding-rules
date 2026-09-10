Real production code. `upsertIfaceAddrHost` must pick usable IPv4/IPv6 addresses from
a network interface and align config state with them.

### Before

```go
func (c *Config) upsertIfaceAddrHost(iface net.Interface) error {
    addr, err := iface.Addrs()
    if err != nil {
        return fmt.Errorf("network addr: %w", err)
    }
    var (
        addrIP4Added bool
        addrIP6Added bool
    )
    for _, a := range addr {
        ipnet, ok := a.(*net.IPNet)
        if !ok || !ipnet.IP.IsGlobalUnicast() {
            continue
        }
        if ipnet.IP.To4() == nil { // validate IP6
            if addrIP6Added { // already added. skip
                continue
            }
            if !c.parseIP6(ipnet) {
                return fmt.Errorf("IP6 %q address is not valid", c.IP6)
            }
            addrIP6Added = true
            continue
        }
        if addrIP4Added {
            continue // already added. skip
        }
        if !c.parseIP4(ipnet) {
            return fmt.Errorf("IP4 %q address is not valid", c.IP4)
        }
        addrIP4Added = true
    }
    if !addrIP4Added && !addrIP6Added {
        return fmt.Errorf("IP address is not valid. IP4: %q, IP6: %q", c.IP4, c.IP6)
    }
    return nil
}
```

48 lines, cognitive complexity 18: type assertions, boolean flags tracking loop
state, three nesting levels, `continue`-driven control flow — and the actual policy
(collect one IPv4 and one IPv6, then reconcile with config) is nowhere stated. The
comments `// validate IP6` and `// already added. skip` are naming blocks that want
to be functions. `parseIP4`/`parseIP6` mutate `c` — the name hides the side effect.

### After

```go
func (c *Config) upsertIfaceAddrHost(iface net.Interface) error {
    addr, err := iface.Addrs()
    if err != nil {
        return fmt.Errorf("network addr: %w", err)
    }

    ipConfig := collectIPConfigFrom(addr)

    if err = c.AlignIPs(ipConfig); err != nil {
        return fmt.Errorf("align config IPs err: %w", err)
    }
    return nil
}
```

Read aloud: get addresses → collect them into an IPConfig → align config with what
was collected. Every line is the same altitude. The collection and validation logic
moved into an `IPConfig` leaf type that unit-tests with literals; the mutating
helpers were renamed `alignIPv4`/`alignIPv6` — "align" admits the side effect that
"parse" hid. Full worked study, including the leaf type and the test payoff:
`../examples/storify-leaf-type.md`.
