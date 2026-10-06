# Over-Abstraction Case: The CIDRPresence Wrapper

Demonstrates: R1

A real refactoring where an extraction was tried, rejected, and replaced with two
cheaper alternatives. This is the case law for R1's over-abstraction trap: what a
correct refutation of a proposed type looks like.

## The setting

During the refactor of the cluster network-settings parser (`alignCidrArgs`,
originally 60 lines mixing `URLSearchParams` string parsing, boolean flag tracking,
and triplicated `switch` arms), two booleans tracked related state:

```typescript
let isClusterCidrSet = false
let isServerCidrSet = false
// ... a parsing loop over the form's values sets them ...
if (isClusterCidrSet && isServerCidrSet) {
  return // both set, nothing to do
}
```

Grouping them into a `CIDRConfig` domain type was a clear win (related data that
travels together, a query method that reads like English). The trap appeared one
step further: the temptation to wrap each boolean in its own type.

## The extraction that was tried

```typescript
// CIDRPresence — a wrapper that adds NO value
class CIDRPresence {
  constructor(private readonly value: boolean) {}

  isSet(): boolean {
    return this.value // just unwraps the boolean!
  }
}

const CIDR_PRESENT = new CIDRPresence(true)

class CIDRConfig {
  clusterCidr: CIDRPresence = CIDR_PRESENT // wrapped boolean
  serviceCidr: CIDRPresence = CIDR_PRESENT // wrapped boolean

  areBothSet(): boolean {
    return this.clusterCidr.isSet() && this.serviceCidr.isSet()
  }
}
```

## Why it was rejected

1. **8 lines of code** for a trivial wrapper.
2. **One method** that just unwraps: `return this.value`.
3. **No type safety gained** — still just a boolean underneath; nothing invalid is
   made unrepresentable, and `new CIDRPresence(true)` admits exactly what `true` admits.
4. **Not more readable.** Compare `config.clusterCidr.isSet()` (wrapper) with
   `config.clusterCidrSet` (good naming). The honest question — is the method call
   *significantly* clearer? — answers itself: no.
5. **No validation, no logic, no invariants** — pure ceremony. On R1's scorecard this
   scores 0-1: LOW priority, do not create the type.
6. **Increases cognitive load** — one more class to understand, for nothing.

The rejection also identified the *real* need hiding under the proposal: **controlled
mutation**. Only the parsing code should be able to set these flags — and the wrapper
type does not deliver that (its fields were still freely settable). Naming the actual
need is what makes the cheaper alternatives findable.

## Cheaper alternative 1 — better naming

When the need is only clarity, rename and stop:

```typescript
interface CIDRConfig {
  clusterCidrSet: boolean
  serviceCidrSet: boolean
}
```

`config.clusterCidrSet` reads exactly as well as `config.clusterCidr.isSet()`, at
zero ceremony. Acceptable when mutation discipline isn't a concern (small, disciplined
surface; short-lived value).

## Cheaper alternative 2 — private fields + accessors (chosen)

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

## The decision, tabulated

| Approach | Types | Readability | Safety | Ceremony | Verdict |
|----------|-------|-------------|--------|----------|---------|
| `CIDRPresence` wrapper | 6 | Good | Low | High | ❌ Over-abstraction |
| Public bool fields (naming) | 5 | Good | Low | Low | ⚠️ Acceptable for disciplined scope |
| Private bools + accessors | 5 | Good | **High** | Low | ✅ Chosen |

## The decision questions

Before creating a wrapper type, ask:

1. Does it have >1 meaningful method with logic — not just unwrapping?
2. Does it enforce invariants or validation?
3. Is the need actually *controlled mutation*? → private fields + accessors, not a
   wrapper.
4. Is the method call **significantly** clearer than good naming?
5. Does it hide complex implementation?

Mostly NO → use primitives with good naming, or private fields when mutation must be
controlled. (Score it with R1's scorecard; this wrapper scores 0.)

## The skeptic's operating rule

**A refutation must always propose the cheaper alternative — never just "no".**

Rejecting `CIDRPresence` was legitimate only because the rejection came with a design
that met the real need (controlled mutation) at lower cost. A bare "don't create the
type" would have left the original defect — uncontrolled mutation of the flags — in
place. The skeptic's job is therefore two moves, always together: name the need the
proposal was groping toward, then meet it more cheaply — better naming when the need
is clarity, private fields + accessors when the need is controlled mutation, and a
real type (per R1) only when the need is validation or behavior.
