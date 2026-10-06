Production-shaped code from a settings hook. `alignIpConfig` must pick usable IPv4
and IPv6 addresses from a device's reported network interface and align the `Config`
form state with them.

### Before

```typescript
// Sets any IP from the reported interface or throws if the configured IP does not match it.
export function alignIpConfig(config: Config, iface: ReportedInterface): void {
  let addrIp4Added = false
  let addrIp6Added = false
  for (const a of iface.addresses) {
    if (a.scope !== 'global') {
      logger.debug('not a global unicast address', { address: a.address })
      continue
    }
    if (a.family === 'inet6') { // validate IP6
      if (addrIp6Added) { // already added. skip
        continue
      }
      if (!parseIp6(config, a.address)) {
        throw new Error(`IP6 "${config.ipv6}" address is not valid`)
      }
      addrIp6Added = true
      continue
    }
    if (addrIp4Added) {
      continue // already added. skip
    }
    if (!parseIp4(config, a.address)) {
      throw new Error(`IP4 "${config.ipv4}" address is not valid`)
    }
    addrIp4Added = true
  }

  if (!addrIp4Added && !addrIp6Added) {
    throw new Error(`IP address is not valid. IP4: "${config.ipv4}", IP6: "${config.ipv6}"`)
  }
}
```

Thirty-three lines, cognitive complexity 17: a discriminant check, boolean flags
tracking loop state, three nesting levels, `continue`-driven control flow — and the
actual policy (collect one IPv4 and one IPv6, then reconcile with the form state) is
nowhere stated. The comments `// validate IP6` and `// already added. skip` are
naming blocks that want to be functions. `parseIp4`/`parseIp6` write into `config` —
the name hides the side effect.

### After

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

Read aloud: collect the addresses into an IPConfig → align config with what was
collected. Every line is the same altitude. The collection and validation logic
moved into an `IPConfig` leaf type that unit-tests with literals: `addAddress` keeps
the first global IPv4 and the first global IPv6, so "already added" is a question the
collected state answers and the two boolean flags have no reason to exist. The
mutating helpers were renamed `alignIpv4`/`alignIpv6` — "align" admits the side
effect that "parse" hid. In a React repository the fat function is as often a
component body or an effect: the same `let` flags and nested `if`s inside a
`useEffect`, or a render tree whose ternaries nest three deep; the extracted leaf is
a pure function or a custom hook, and `react/no-unstable-nested-components` fires
when the extraction is done in place inside the component instead. Full worked
study, including the leaf type and the test payoff:
`../examples/storify-leaf-type.md`.
