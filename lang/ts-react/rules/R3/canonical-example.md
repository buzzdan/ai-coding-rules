Production-shaped code from a settings hook. `alignIpConfig` must pick usable IPv4
and IPv6 addresses from a device's reported network interface and align the `Config`
form state with them.

### Before

```typescript
function alignIpConfig(config: Config, iface: ReportedInterface): Config {
  if (iface.addrs.length === 0) {
    throw new ConfigError(`network addr: ${iface.name} reported no addresses`)
  }
  const draft = { ...config }
  let ip4Added = false
  let ip6Added = false
  for (const a of iface.addrs) {
    if (a.scope !== 'global') {
      continue
    }
    if (a.family === 'inet6') { // validate IP6
      if (ip6Added) { // already added. skip
        continue
      }
      if (!parseIp6(draft, a)) {
        throw new ConfigError(`IP6 '${draft.ip6}' address is not valid`)
      }
      ip6Added = true
      continue
    }
    if (ip4Added) {
      continue // already added. skip
    }
    if (!parseIp4(draft, a)) {
      throw new ConfigError(`IP4 '${draft.ip4}' address is not valid`)
    }
    ip4Added = true
  }
  if (!ip4Added && !ip6Added) {
    throw new ConfigError(`IP address is not valid. IP4: '${draft.ip4}', IP6: '${draft.ip6}'`)
  }
  return draft
}
```

Thirty-three lines, cognitive complexity 18: a discriminant check, boolean flags
tracking loop state, three nesting levels, `continue`-driven control flow — and the
actual policy (collect one IPv4 and one IPv6, then reconcile with the form state) is
nowhere stated. The comments `// validate IP6` and `// already added. skip` are
naming blocks that want to be functions. `parseIp4`/`parseIp6` write into `draft` —
the name hides the side effect.

### After

```typescript
function alignIpConfig(config: Config, iface: ReportedInterface): Config {
  if (iface.addrs.length === 0) {
    throw new ConfigError(`network addr: ${iface.name} reported no addresses`)
  }

  const ipConfig = collectIpConfig(iface.addrs)

  return alignIps(config, ipConfig)
}
```

Read aloud: get addresses → collect them into an IPConfig → align config with what
was collected. Every line is the same altitude. The collection and validation logic
moved into an `IPConfig` leaf type that unit-tests with literals; `collectIpConfig`
is a `filter` over the global addresses and two `find`s, first IPv4 and first IPv6,
so the two boolean flags have no reason to exist. The mutating helpers were renamed
`alignIpv4`/`alignIpv6` — "align" admits the side effect that "parse" hid. In a
React repository the fat function is as often a component body or an effect: the
same `let` flags and nested `if`s inside a `useEffect`, or a render tree whose
ternaries nest three deep; the extracted leaf is a pure function or a custom hook,
and `react/no-unstable-nested-components` fires when the extraction is done in place
inside the component instead. Full worked study, including the leaf type and the
test payoff: `../examples/storify-leaf-type.md`.
