When the need is controlled mutation rather than validation or logic, TypeScript's
spelling of private fields with read-only accessors is `readonly` fields plus one
factory: every field is readable, none is assignable after construction, and the
module exports no way to build one but the parser:

```typescript
/** Which CIDR configurations are present. Built only by parseCidrConfig. */
export interface CIDRConfig {
  readonly clusterCidrSet: boolean
  readonly serviceCidrSet: boolean
}

export function areBothSet(config: CIDRConfig): boolean {
  return config.clusterCidrSet && config.serviceCidrSet
}

export function parseCidrConfig(params: URLSearchParams): CIDRConfig {
  const clusterCidrSet = params.has('cluster-cidr') // the one place the flags are decided
  const serviceCidrSet = params.has('service-cidr')
  return Object.freeze({ clusterCidrSet, serviceCidrSet })
}
```

Why this beat the wrapper:

- **Same safety** — `readonly` makes `config.clusterCidrSet = true` a compile error,
  and `Object.freeze` in the parser makes it a run-time `TypeError` too for a value
  that reached a caller through `unknown`; only the parser decides the values.
- **4 fewer lines** than the `CIDRPresence` approach, and one type instead of two.
- **Same readability** — `config.clusterCidrSet` is just as clear as
  `config.clusterCidr.isSet()`.
- **No wrapper ceremony** — the fields are what they are: booleans.
