```typescript
/** The first usable global-unicast IPv4 and IPv6 address of a reported interface. */
export class IPConfig {
  ip4 = ''
  ip6 = ''

  addAddress(a: ReportedAddress): void {
    if (a.scope !== 'global') {
      logger.debug('not a global unicast address', { address: a.address })
      return
    }

    if (a.family === 'inet') {
      if (this.ip4 !== '') {
        return // already added
      }
      this.ip4 = a.address
      return
    }

    if (this.ip6 !== '') {
      return // already added
    }
    this.ip6 = a.address
  }

  validate(): void {
    if (this.ip4 === '' && this.ip6 === '') {
      throw new Error('IP addresses are not found')
    }
  }
}
```

The boolean flags are gone: "already added" is now a question the collected state
answers (`this.ip4 !== ''`), and the `continue`s became early `return`s — each
address is handled by one small decision tree instead of steering a shared loop.
`IPConfig` lives in its own `ipConfig.ts` beside the hook, imports no React and
never renders: a leaf a test reaches with literals, no provider tree in sight.
