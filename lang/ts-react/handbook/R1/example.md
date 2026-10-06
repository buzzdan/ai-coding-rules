```typescript
// ❌ the rule lives at the call site, twice, and 0 means "none"
function managementPort(spec: ServiceSpec): number {
  for (const p of spec.ports) {
    if (p.name === 'weka-api' && p.port > 0 && p.port <= 65535) return p.port
  }
  for (const p of spec.ports) {
    if (p.port > 0 && p.port <= 65535) return p.port
  }
  return 0
}

// ✅ a Port cannot exist out of range; "first valid" collapses to "first"
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

export class Ports {
  constructor(private readonly items: readonly Port[]) {}
  firstNamed(name: string): Port | undefined {
    return this.items.find((p) => p.name === name)
  }
  first(): Port | undefined {
    return this.items[0]
  }
}

// ❌ a shape crosses the boundary; the caller pokes the method out of it
const BEARER = 'Bearer '

function bearerToken(headers: Record<string, string>): string | undefined {
  for (const [name, value] of Object.entries(headers)) {
    if (name === 'Authorization' && value.startsWith(BEARER)) return value.slice(BEARER.length)
  }
  return undefined
}

// ✅ the container has a name, and the loop is its method
export class RequestHeaders {
  private readonly raw: ReadonlyMap<string, string>
  constructor(raw: Iterable<readonly [string, string]>) {
    this.raw = new Map(raw)
  }
  authToken(): string | undefined {
    const value = this.raw.get('Authorization')
    return value?.startsWith(BEARER) ? value.slice(BEARER.length) : undefined
  }
}
```

> **In TypeScript:** absence is a declared `Port | undefined` that every caller
> narrows, checked by `strict`; `Map.get` and `Array.prototype.find` are the model. A
> `0`, `''`, `-1` or `null` returned from a signature that promises `Port` is a
> sentinel and a finding, and `as Port`, a `!` or an `@ts-expect-error` is its
> silenced form. Never a `[Port, boolean]` tuple. A bare `type PortNumber = number`,
> or a brand without a validating factory, scores zero on the scorecard: it is erased
> and admits every literal. A `Record<string, string>` or a tuple returned from a
> function is a shape, not a concept: read what the receivers do with it, and name the
> type. A nested annotation (`Record<string, string[]>`,
> `[Record<string, unknown>, string]`) is always a missing named type; `readonly T[]`
> is one level, not nesting.
