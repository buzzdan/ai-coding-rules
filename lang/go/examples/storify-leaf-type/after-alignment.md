```go
func (c *Config) AlignIPs(ipConfig IPConfig) error {
    if err := ipConfig.Validate(); err != nil {
        return fmt.Errorf("ip config is not valid: %w", err)
    }

    if err := c.alignIPv4(ipConfig.IP4); err != nil {
        return fmt.Errorf("align IPv4 err: %w", err)
    }
    if err := c.alignIPv6(ipConfig.IP6); err != nil {
        return fmt.Errorf("align IPv6 err: %w", err)
    }
    return nil
}

func (c *Config) alignIPv4(ip string) error {
    if c.IPv4 == ip {
        return nil // matches interface
    }
    if c.IPv4 == anyIPv4 || c.IPv4 == "" {
        c.IPv4 = ip // use first ip found from interface
        return nil
    }
    return fmt.Errorf("existing IPv4 [%s] mismatch configured [%s]", ip, c.IPv4)
}

func (c *Config) alignIPv6(ip string) error {
    if c.IPv6 == ip {
        return nil
    }
    if c.IPv6 == anyIPv6 || c.IPv6 == "" {
        c.IPv6 = ip
        return nil
    }
    return fmt.Errorf("existing IPv6 [%s] mismatch configured [%s]", ip, c.IPv6)
}
```

`parseIP4` → `alignIPv4`: "align" admits the mutation that "parse" hid, and the
boolean returns became errors that say *what* mismatched.
