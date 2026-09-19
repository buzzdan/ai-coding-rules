```go
// upsertIfaceAddrHost sets any IP from iface or returns error if provided IP not match to the interface
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

func collectIPConfigFrom(addresses []net.Addr) IPConfig {
    var ipConfig IPConfig
    for _, a := range addresses {
        ipConfig.AddAddress(a)
    }
    return ipConfig
}
```
