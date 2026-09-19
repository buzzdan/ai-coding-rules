```go
// upsertIfaceAddrHost sets any IP from iface or returns error if provided IP not match to the interface
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
            logger.Debug().Str("addr", a.String()).Msg("Not a global unicast address")
            continue
        }
        if ipnet.IP.To4() == nil { // validate IP6
            if addrIP6Added { // already added. skip
                continue
            }
            if !c.parseIP6(ipnet) {
                return fmt.Errorf("IP6 %q address is not valid", c.IP6)
            }
            logger.Debug().Str("ip6", c.IP6).Msg("set IP6")
            addrIP6Added = true
            continue
        }
        if addrIP4Added {
            continue // already added. skip
        }
        if !c.parseIP4(ipnet) {
            return fmt.Errorf("IP4 %q address is not valid", c.IP4)
        }
        logger.Debug().Str("ip4", c.IP6).Msg("set IP4")
        addrIP4Added = true
    }

    if !addrIP4Added && !addrIP6Added {
        return fmt.Errorf("IP address is not valid. IP4: %q, IP6: %q", c.IP4, c.IP6)
    }

    return nil
}

func (c *Config) parseIP4(ipnet *net.IPNet) bool {
    if c.IP4 == ipnet.IP.To4().String() {
        return true
    }
    if c.IP4 == anyIPv4 || c.IP4 == "" {
        // use first ip found from interface
        c.IP4 = ipnet.IP.To4().String()
        return true
    }
    return false
}

func (c *Config) parseIP6(ipnet *net.IPNet) bool {
    if c.IP6 == ipnet.IP.To16().String() {
        return true
    }
    if c.IP6 == anyIPv6 || c.IP6 == "" {
        // use first ip found from interface
        c.IP6 = ipnet.IP.To16().String()
        return true
    }
    return false
}
```
