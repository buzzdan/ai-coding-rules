Before, exercising any of this meant faking an `Interface` — building a network
scenario to check "keep the first IPv4". After, the leaf is tested with constructed
addresses and no orchestration in sight:

```python
def test_ip_config_add_address_keeps_first_ipv4() -> None:
    cfg = netconfig.IPConfig()

    cfg.add_address(Addr("192.168.1.1"))
    cfg.add_address(Addr("192.168.1.2"))  # second one is ignored

    assert cfg.ip4 == "192.168.1.1"


def test_ip_config_validate_rejects_nothing_collected() -> None:
    cfg = netconfig.IPConfig()  # nothing collected

    with pytest.raises(ValueError, match="not found"):
        cfg.validate()
```

100% coverage on `IPConfig` costs a handful of literal-input cases. The orchestrator
(`upsert_iface_addr_host` + `align_ips`) keeps an integration-style test covering
the seam — collection feeding alignment — per R7.
