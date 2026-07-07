# Over-Abstraction Case: The CIDRPresence Wrapper

Demonstrates: R1

A real refactoring where an extraction was tried, rejected, and replaced with two
cheaper alternatives. This is the case law for R1's over-abstraction trap: what a
correct refutation of a proposed type looks like.

## The setting

During the refactor of a K3s configuration function (`alignCIDRArgs`, originally 60
lines mixing string parsing, boolean flag tracking, and triplicated switch cases),
two booleans tracked related state:

```go
var (
    isClusterCIDRSet bool
    isServerCIDRSet  bool
)
// ... a parsing loop sets them ...
if isClusterCIDRSet && isServerCIDRSet {
    return // both set, nothing to do
}
```

Grouping them into a `CIDRConfig` domain type was a clear win (related data that
travels together, a query method that reads like English). The trap appeared one
step further: the temptation to wrap each boolean in its own type.

## The extraction that was tried

```go
// CIDRPresence — a wrapper that adds NO value
type CIDRPresence bool

const (
    cidrPresent CIDRPresence = true
)

func (p CIDRPresence) IsSet() bool {
    return bool(p) // just unwraps the bool!
}

type CIDRConfig struct {
    ClusterCIDR CIDRPresence // wrapped bool
    ServiceCIDR CIDRPresence // wrapped bool
}

func (c CIDRConfig) AreBothSet() bool {
    return c.ClusterCIDR.IsSet() && c.ServiceCIDR.IsSet()
}
```

## Why it was rejected

1. **8 lines of code** for a trivial wrapper.
2. **One method** that just unwraps: `return bool(p)`.
3. **No type safety gained** — still just a bool underneath; nothing invalid is made
   unrepresentable.
4. **Not more readable.** Compare `config.ClusterCIDR.IsSet()` (wrapper) with
   `config.ClusterCIDRSet` (good naming). The honest question — is the method call
   *significantly* clearer? — answers itself: no.
5. **No validation, no logic, no invariants** — pure ceremony. On R1's scorecard this
   scores 0-1: LOW priority, do not create the type.
6. **Increases cognitive load** — one more type to understand, for nothing.

The rejection also identified the *real* need hiding under the proposal: **controlled
mutation**. Only the parsing code should be able to set these flags — and the wrapper
type does not deliver that (its fields were still freely settable). Naming the actual
need is what makes the cheaper alternatives findable.

## Cheaper alternative 1 — better naming

When the need is only clarity, rename and stop:

```go
type CIDRConfig struct {
    ClusterCIDRSet bool
    ServiceCIDRSet bool
}
```

`config.ClusterCIDRSet` reads exactly as well as `config.ClusterCIDR.IsSet()`, at
zero ceremony. Acceptable when mutation discipline isn't a concern (small, disciplined
surface; short-lived value).

## Cheaper alternative 2 — private fields + accessors (chosen)

When the need is controlled mutation rather than validation or logic, private fields
with read-only accessors deliver compiler-enforced safety without a wrapper:

```go
// CIDRConfig — which CIDR configurations are present.
// Private fields: can only be set by ParseCIDRConfig.
type CIDRConfig struct {
    clusterCIDRSet bool
    serviceCIDRSet bool
}

func (c CIDRConfig) ClusterCIDRSet() bool { return c.clusterCIDRSet }
func (c CIDRConfig) ServiceCIDRSet() bool { return c.serviceCIDRSet }

func (c CIDRConfig) AreBothSet() bool {
    return c.clusterCIDRSet && c.serviceCIDRSet
}
```

Why this beat the wrapper:

- **Same safety** — the compiler enforces that only the parser (in the same package)
  can set the values; external code gets read-only access.
- **4 fewer lines** than the `CIDRPresence` approach.
- **Same readability** — `ClusterCIDRSet()` is just as clear as `ClusterCIDR.IsSet()`.
- **No wrapper ceremony** — the fields are what they are: bools.

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
