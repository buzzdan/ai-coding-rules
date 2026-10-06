```typescript
function alignIps(config: Config, ipConfig: IPConfig): void {
  ipConfig.validate()
  alignIpv4(config, ipConfig.ip4)
  alignIpv6(config, ipConfig.ip6)
}

function alignIpv4(config: Config, ip: string): void {
  if (config.ipv4 === ip) {
    return // matches interface
  }
  if (config.ipv4 === ANY_IPV4 || config.ipv4 === '') {
    config.ipv4 = ip // use first ip found from interface
    return
  }
  throw new Error(`existing IPv4 [${ip}] mismatch configured [${config.ipv4}]`)
}

function alignIpv6(config: Config, ip: string): void {
  if (config.ipv6 === ip) {
    return
  }
  if (config.ipv6 === ANY_IPV6 || config.ipv6 === '') {
    config.ipv6 = ip
    return
  }
  throw new Error(`existing IPv6 [${ip}] mismatch configured [${config.ipv6}]`)
}
```

`parseIp4` → `alignIpv4`: "align" admits the mutation that "parse" hid, and the
boolean returns became thrown errors that say *what* mismatched.
