```typescript
/** Sets any IP from the reported interface, or throws when the configured IP does not match it. */
export function alignIpConfig(config: Config, iface: ReportedInterface): void {
  const ipConfig = collectIpConfigFrom(iface.addresses)
  alignIps(config, ipConfig)
}

function collectIpConfigFrom(addresses: readonly ReportedAddress[]): IPConfig {
  const ipConfig = new IPConfig()
  for (const a of addresses) {
    ipConfig.addAddress(a)
  }
  return ipConfig
}
```
