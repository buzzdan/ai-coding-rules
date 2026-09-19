```go
// IPConfig collects the first usable global-unicast IPv4 and IPv6 address.
type IPConfig struct {
    IP4 string
    IP6 string
}

func (c *IPConfig) AddAddress(a net.Addr) {
    ipnet, ok := a.(*net.IPNet)
    if !ok || !ipnet.IP.IsGlobalUnicast() {
        logger.Debug().Str("addr", a.String()).Msg("Not a global unicast address")
        return
    }

    if ipnet.IP.To4() != nil {
        if len(c.IP4) > 0 {
            return // already added
        }
        c.IP4 = ipnet.IP.To4().String()
        return
    }

    if len(c.IP6) > 0 {
        return // already added
    }
    c.IP6 = ipnet.IP.To16().String()
}

func (c *IPConfig) Validate() error {
    if len(c.IP4) == 0 && len(c.IP6) == 0 {
        return errors.New("IP addresses are not found")
    }
    return nil
}
```

The boolean flags are gone: "already added" is now a question the collected state
answers (`len(c.IP4) > 0`), and the `continue`s became early `return`s — each address
is handled by one small decision tree instead of steering a shared loop.
