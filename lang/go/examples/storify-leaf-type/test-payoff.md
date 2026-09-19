Before, exercising any of this meant mocking `net.Interface` — building a network
scenario to check "keep the first IPv4". After, the leaf is tested with constructed
addresses and no orchestration in sight:

```go
func TestIPConfig_AddAddress_KeepsFirstIPv4(t *testing.T) {
    var cfg netconfig.IPConfig

    cfg.AddAddress(ipv4Addr(t, "192.168.1.1"))
    cfg.AddAddress(ipv4Addr(t, "192.168.1.2")) // second one is ignored

    assert.Equal(t, "192.168.1.1", cfg.IP4)
}

func TestIPConfig_Validate_Error(t *testing.T) {
    var cfg netconfig.IPConfig // nothing collected

    assert.Error(t, cfg.Validate())
}

func ipv4Addr(t *testing.T, ip string) net.Addr {
    t.Helper()
    return &net.IPNet{IP: net.ParseIP(ip), Mask: net.CIDRMask(24, 32)}
}
```

100% coverage on `IPConfig` costs a handful of literal-input cases. The
orchestrator (`upsertIfaceAddrHost` + `AlignIPs`) keeps an integration-style test
covering the seam — collection feeding alignment — per R7.
