Before, exercising any of this meant building a whole `Config` draft and a
`ReportedInterface` fixture — a network scenario to check "keep the first IPv4" —
and asserting through the draft's mutation. After, the leaf is tested in a colocated
`ipConfig.test.ts` with literal addresses, no render and no MSW handler in sight:

```typescript
const inet = (address: string): ReportedAddress => ({ address, family: 'inet', scope: 'global' })

describe('IPConfig', () => {
  it('keeps the first IPv4', () => {
    const cfg = new IPConfig()

    cfg.addAddress(inet('192.168.1.1'))
    cfg.addAddress(inet('192.168.1.2')) // second one is ignored

    expect(cfg.ip4).toBe('192.168.1.1')
  })

  it('rejects nothing collected', () => {
    const cfg = new IPConfig() // nothing collected

    expect(() => cfg.validate()).toThrow('not found')
  })
})
```

100% coverage on `IPConfig` costs a handful of literal-input cases. The orchestrator
(`alignIpConfig` + `alignIps`) keeps an integration-style test covering the seam —
collection feeding alignment — per R7.
