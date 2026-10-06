The Port case, in TypeScript. The dashboard renders a link to a cluster's management
console. The API returns a service description with ports, and the UI must pick the
management port: prefer the port named `weka-api`, else fall back to the first valid
port.

### Before

```typescript
function managementPort(spec: ServiceSpec): number {
  for (const p of spec.ports) {
    if (p.name === 'weka-api' && p.port > 0 && p.port <= 65535) {
      return p.port
    }
  }
  for (const p of spec.ports) {
    if (p.port > 0 && p.port <= 65535) {
      return p.port
    }
  }
  return 0
}
```

Four defects in twelve lines:

- The validity rule `p.port > 0 && p.port <= 65535` is duplicated across the two
  loops — two copies that can drift independently.
- Two abstractions exist only as unnamed boolean expressions: "valid port" and
  "named management port".
- The logic runs on the wire DTO inside the hook that fetched it, so it is testable
  only by rendering the page over an MSW fixture of the whole service response.
- `return 0` is a sentinel: validity is encoded in-band, and every caller must know
  that `0` means "none" — the `<a href>` that forgets renders a link to port `0`.

### Stage 1 — self-validating types with constructors

```typescript
/** The wire DTO: exactly what the API returned, no rules. */
export interface ServicePort {
  readonly name: string
  readonly port: number
}

/** A named, validated service port; it cannot exist out of range. */
export interface Port {
  readonly name: string
  readonly number: number
}

export function parsePort(name: string, number: number): Port {
  if (!Number.isInteger(number) || number <= 0 || number > 65535) {
    throw new RangeError(`port '${name}': ${number} out of range 1-65535`)
  }
  return { name, number }
}

/** A collection of valid ports. */
export class Ports {
  constructor(private readonly items: readonly Port[]) {}

  firstNamed(name: string): Port | undefined {
    return this.items.find((p) => p.name === name)
  }

  first(): Port | undefined {
    return this.items[0]
  }

  management(): Port | undefined {
    // Stage 2 relocates this method — the "weka-api" preference is feature
    // policy, not networking vocabulary.
    return this.firstNamed('weka-api') ?? this.first()
  }
}

// Drops invalid wire entries — a documented decision that mirrors the original
// skip-and-fall-back behaviour: an invalid port was never chosen before; now it
// never exists.
export function parsePorts(wire: readonly ServicePort[]): Ports {
  const items: Port[] = []
  for (const w of wire) {
    try {
      items.push(parsePort(w.name, w.port))
    } catch {
      continue
    }
  }
  return new Ports(items)
}
```

The payoff, stated plainly: notice what was **not** written. There is no `isValid()`
method and no validity loop anywhere. Self-validation does not move the
`> 0 && <= 65535` check somewhere tidier — it **deletes the concept of a
maybe-invalid port from downstream logic**. Every `Port` inside a `Ports` is valid by
construction, so "find the first valid port" collapses to "find the first port". And
`management()` returns `Port | undefined`, a declared absence that every caller
narrows — never a `0` sentinel that smuggles validity back in-band. Absence that is
exceptional would throw instead; the TypeScript rule is that `undefined` is a
declared absence and never a disguised failure (`R2-self-validating-types.md`).
Types are erased, so the compiler never runs `parsePort`: `readonly` closes
assignment after construction, and the factory is the only production site that
spells a `Port` literal — R2 Q1 greps for the others.

### Stage 2 — placement (R4 rung 3)

`Port`, `Ports`, `firstNamed`, `first` say nothing about Kubernetes or Weka — they
are generic networking vocabulary, so they move to a shared `src/networking/` module
(rung 3 of `R4-helper-placement.md`). The wire adapter `parsePorts` knows the
Kubernetes DTO, so it stays with the feature. The feature policy stays home as a
two-line storified function beside the hook that uses it:

```typescript
const WEKA_API_PORT = 'weka-api'

export function managementPort(ports: Ports): Port | undefined {
  return ports.firstNamed(WEKA_API_PORT) ?? ports.first()
}
```

Teaching point: **promote only the domain-generic parts.** The `WEKA_API_PORT`
constant is feature policy and stays in the feature — a shared module that knows one
feature's port names is not shared vocabulary, it is leaked policy.

### Stage 3 — testing contrast

Before, exercising `managementPort()` meant rendering the page over an MSW fixture of
the whole service response — mounting a route to check a range predicate. After, the
logic is a leaf and its rung-0 unit tests (the composition ladder's bottom rung — see
@testing) are array literals against `Ports`; no render, no provider, no handler:

```typescript
describe('Ports', () => {
  it('prefers the named port', () => {
    const api = parsePort('weka-api', 14000)
    const web = parsePort('http', 80)

    expect(new Ports([web, api]).firstNamed('weka-api')).toBe(api)
  })

  it('rejects an out-of-range port number', () => {
    expect(() => parsePort('weka-api', 70000)).toThrow(/out of range/)
  })
})
```

### The opposite failure: don't over-extract

```typescript
// ❌ Ceremony, not a type: no rule, no behaviour — every number is as valid as any other.
type ReplicaCount = number

// ❌ A brand with no validating constructor: every call site casts, nothing checks.
type DeviceName = string & { readonly __brand: 'DeviceName' }

class Name { // ❌ the only "method" unwraps
  constructor(private readonly value: string) {}

  toString(): string {
    return this.value
  }
}
```

Score it against the scorecard below: no validation (+0), no meaningful methods (+0),
one call site (+0) → Score 0. Keep the `number`; if a name is wanted, a well-named
variable or a non-exported helper in the same module is the whole answer
(`R4-helper-placement.md`, rung 1). A bare alias is erased and admits every literal,
and a brand without a factory admits every `as DeviceName`, so neither earns anything
on the invariant line either. Deep worked rejection with the cheaper alternatives:
`../examples/overabstraction-cidr.md`.
