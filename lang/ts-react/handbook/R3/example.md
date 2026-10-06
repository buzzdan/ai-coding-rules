```typescript
// ❌ flags track the loop, comments name the blocks, the policy is nowhere stated
export function alignIpConfig(config: Config, iface: ReportedInterface): void {
  let addrIp4Added = false
  let addrIp6Added = false
  for (const a of iface.addresses) {
    if (a.scope !== 'global') continue
    if (a.family === 'inet6') { // validate IP6
      if (addrIp6Added) continue // already added. skip
      if (!parseIp6(config, a.address)) throw new Error(`IP6 "${config.ipv6}" is not valid`)
      addrIp6Added = true
      continue
    }
    // ... the IPv4 twin of the block above, then the "nothing added" check
  }
}

// ✅ the story in two named steps; the loop moved onto a type that owns it
export function alignIpConfig(config: Config, iface: ReportedInterface): void {
  const ipConfig = collectIpConfigFrom(iface.addresses)
  alignIps(config, ipConfig)
}

function collectIpConfigFrom(addresses: readonly ReportedAddress[]): IPConfig {
  const ipConfig = new IPConfig()
  for (const a of addresses) ipConfig.addAddress(a)
  return ipConfig
}
```

> **In TypeScript:** a name reveals its side effect: `align`/`upsert`/`set` mutate,
> `parse`/`validate`/`is` never do. A `parseIp4` that writes `config.ipv4` is a
> storifying bug even when the flow reads well. In React the fat function is as often
> a component body or an effect: the same `let` flags and nested `if`s inside a
> `useEffect`, or a render tree whose ternaries nest three deep. The extracted leaf is
> a pure function or a custom hook, and `react/no-unstable-nested-components` fires
> when the extraction is done in place inside the component.
