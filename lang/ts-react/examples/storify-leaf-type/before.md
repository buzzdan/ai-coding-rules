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
      logger.debug('set IP6', { ipv6: config.ipv6 })
      addrIp6Added = true
      continue
    }
    if (addrIp4Added) {
      continue // already added. skip
    }
    if (!parseIp4(config, a.address)) {
      throw new Error(`IP4 "${config.ipv4}" address is not valid`)
    }
    logger.debug('set IP4', { ipv4: config.ipv6 })
    addrIp4Added = true
  }

  if (!addrIp4Added && !addrIp6Added) {
    throw new Error(`IP address is not valid. IP4: "${config.ipv4}", IP6: "${config.ipv6}"`)
  }
}

function parseIp4(config: Config, ip: string): boolean {
  if (config.ipv4 === ip) {
    return true
  }
  if (config.ipv4 === ANY_IPV4 || config.ipv4 === '') {
    // use first ip found from interface
    config.ipv4 = ip
    return true
  }
  return false
}

function parseIp6(config: Config, ip: string): boolean {
  if (config.ipv6 === ip) {
    return true
  }
  if (config.ipv6 === ANY_IPV6 || config.ipv6 === '') {
    // use first ip found from interface
    config.ipv6 = ip
    return true
  }
  return false
}
```
