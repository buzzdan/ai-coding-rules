# Storify + Leaf Type Case: From Fat Function to Lean Orchestration

Demonstrates: R3, R1, R2

A real refactoring from a production codebase: a 48-line function mixing iteration,
validation, collection, and mutation becomes a 3-step story, with the juicy logic
extracted into a leaf type that unit-tests without mocks. This is the case law for
R3's core move — storifying discovers the leaf type — and for what the developer
actually shipped, including the imperfections and the next steps they left on the
table.

## The setting

`alignIpConfig`, in the `useNetworkSettings` hook, must inspect the interface a device
reported (`ReportedInterface`), pick usable global-unicast IPv4/IPv6 addresses, and
reconcile the IP fields of the `Config` draft with what it found.

## Before

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

## The smells, named

1. **Fat function** — 33 lines, cognitive complexity 17 (`sonarjs/cognitive-complexity`
   fires at the house threshold of 15), cyclomatic complexity 10 at
   `sonarjs/cyclomatic-complexity`'s ceiling, nesting depth 3: collection,
   validation, and config mutation crammed into one body.
2. **Mixed abstraction levels (R3)** — `a.scope`/`a.family` discrimination of the
   reported address in the same body as the business decision "is this
   configuration valid".
3. **Boolean flags tracking loop state** — `addrIp4Added`/`addrIp6Added` are set
   inside the loop and read after it: the classic signature of a collection type
   waiting to absorb the loop.
4. **Comments naming blocks** — `// validate IP6`, `// already added. skip`: each is
   an extraction order (R3), a function name written as prose.
5. **Dishonest names** — `parseIp4`/`parseIp6` mutate `config.ipv4`/`config.ipv6`;
   "parse" promises read-only. (Note the real-world bug it helped hide: the before
   code logs `config.ipv6` under "set IP4" — a copy-paste slip that a smaller, honest
   function would have made glaring.)
6. **No leaf types (R1)** — all logic runs against the whole `Config` draft, so
   nothing is testable without constructing a `Config` and a `ReportedInterface`
   scenario.

The core problem: the juicy logic (which addresses count, how many of each family
to keep) is trapped inside an orchestration function. The fix is not to reshuffle
the fat function — it is to give that logic an owner.

## Step 1 — separate orchestration from logic

The function does three things: **collect** candidate IPs from the interface
(logic), **validate** the result (logic), **align** the config with what was found
(orchestration + logic). Collection and validation don't need `Config` at all —
that's the leaf type.

## After — the storified orchestrator

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

Read aloud: get addresses → collect them into an IPConfig → align our config with
what we collected. No nested ifs, no `continue`, no boolean flags — every line at
one altitude.

## After — the extracted leaf type

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

## After — the alignment side, honestly named

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

## The test payoff

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

## Metrics

| | Before | After |
|---|---|---|
| Main function | 33 lines | 4 lines |
| Cyclomatic complexity | 10 | max 5 per function (`addAddress`) |
| Cognitive complexity (`sonarjs/cognitive-complexity`) | 17 | max 5 per function |
| Nesting depth | 3 | 2 |
| Testable without a `Config` + `ReportedInterface` scenario | nothing | all of `IPConfig` |

## Decision points

1. **Storifying discovered the type.** The extraction order was: name the steps
   (collect → validate → align), then notice that "collect" carries its own state —
   the loop flags — and give that state an owner. R3 and R1 are one move here, not
   two.
2. **Honest naming was part of the refactor, not polish.** Renaming
   `parseIp*` → `alignIpv*` changed what readers expect the function to do; the
   copy-paste logging bug in the before code is the kind of defect dishonest names
   incubate.
3. **This is real shipped code, not an ideal.** The developer stopped here, and two
   improvements remain on the table:
   - **R2 is not fully paid.** `IPConfig` is a class with public mutable fields and a
     separate `validate()` that `alignIps` must remember to call — validation the
     type does not own. The stricter move: make collection the constructor — a
     `collectIpConfigFrom(addresses)` that throws on an empty result and returns
     a value with `readonly ip4`/`readonly ip6`, so `validate()` disappears. Then an
     invalid `IPConfig` cannot reach `alignIps` at all (see
     `../rules/R2-self-validating-types.md`).
   - **The IP strings are still primitives.** `ip4: string` re-checks emptiness at
     each use; an optional `ip4?: IPv4Address` — `undefined` as the declared absence,
     a branded type built by one validating factory — would delete those checks.
     Score it before wrapping (`../rules/R1-primitive-obsession.md`).

   Good refactoring knows when to stop — but a review citing this case should name
   these as the next iterations, not treat the shipped state as the ceiling.
