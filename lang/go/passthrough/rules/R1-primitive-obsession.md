# R1 — Primitive Obsession

## Principle

Domain concepts must not travel as raw `string`/`int`/`bool`/`[]T`. When a primitive
carries validation rules, behavior, or a domain name, it becomes a type with a
validating constructor and named methods. The inverse binds equally: a wrapper that
adds no validation, no logic, and no invariant is over-abstraction — score before you wrap.

## Why

A rule enforced on a primitive is enforced at every call site and owned by none: the
check gets duplicated, drifts, and is skipped exactly once — in the code path that
ships the bug. Logic trapped on primitives is also untestable in isolation: you must
construct whatever large object happens to hold the primitive. A domain type gives the
rule one owner (the constructor — see `R2-self-validating-types.md`), gives the
behavior a name, makes invalid values unrepresentable downstream, and turns the logic
into a leaf that unit-tests with literals. Where the extracted type then lives is
`R4-helper-placement.md`.

## Canonical example

Real PR code (weka/goweka#951). `kubeService` wraps a Kubernetes Service DTO and must
pick the management port: prefer the port named `weka-api`, else fall back to the
first valid port.

### Before

```go
func (s kubeService) managementPort() int32 {
    for _, p := range s.Spec.Ports {
        if p.Name == "weka-api" && p.Port > 0 && p.Port <= 65535 {
            return p.Port
        }
    }
    for _, p := range s.Spec.Ports {
        if p.Port > 0 && p.Port <= 65535 {
            return p.Port
        }
    }
    return 0
}
```

Four defects in twelve lines:

- The validity rule `p.Port > 0 && p.Port <= 65535` is duplicated across the two
  loops — two copies that can drift independently.
- Two abstractions exist only as unnamed boolean expressions: "valid port" and
  "named management port".
- The logic lives on a K8s DTO, so it is testable only by constructing a
  `kubeService` around a full Service object.
- `return 0` is a sentinel: validity is encoded in-band, and every caller must know
  that `0` means "none".

### Stage 1 — self-validating types with constructors

```go
// ServicePort is the wire DTO. Its fields stay exported with json tags —
// unexported fields with json tags silently fail to unmarshal (encoding/json
// skips them without error, and every port reads as zero).
type ServicePort struct {
    Name string `json:"name"`
    Port int32  `json:"port"`
}

// Port is a named, validated service port. It cannot exist out of range,
// so no downstream code ever re-checks it.
type Port struct {
    name   string
    number int32
}

func ParsePort(name string, number int32) (Port, error) {
    if number <= 0 || number > 65535 {
        return Port{}, fmt.Errorf("port %q: %d out of range 1-65535", name, number)
    }
    return Port{name: name, number: number}, nil
}

func (p Port) Name() string  { return p.name }
func (p Port) Number() int32 { return p.number }

// Ports is a collection of valid ports.
type Ports []Port

// ParsePorts drops invalid wire entries — a documented decision that mirrors
// the original skip-and-fall-back semantics: an invalid port was never chosen
// before; now it never exists.
func ParsePorts(wire []ServicePort) Ports {
    ports := make(Ports, 0, len(wire))
    for _, w := range wire {
        p, err := ParsePort(w.Name, w.Port)
        if err != nil {
            continue
        }
        ports = append(ports, p)
    }
    return ports
}

func (ps Ports) FirstNamed(name string) (Port, bool) {
    for _, p := range ps {
        if p.name == name {
            return p, true
        }
    }
    return Port{}, false
}

func (ps Ports) First() (Port, bool) {
    if len(ps) == 0 {
        return Port{}, false
    }
    return ps[0], true
}

// Management prefers the port named "weka-api", else the first valid port.
// (Stage 2 relocates this method — the "weka-api" preference is feature
// policy, not networking vocabulary.)
func (ps Ports) Management() (Port, bool) {
    if p, ok := ps.FirstNamed("weka-api"); ok {
        return p, true
    }
    return ps.First()
}
```

The payoff, stated plainly: notice what was **not** written. There is no `IsValid()`
method and no validity loop anywhere. Self-validation does not move the
`> 0 && <= 65535` check somewhere tidier — it **deletes the concept of a
maybe-invalid port from downstream logic**. Every `Port` inside a `Ports` is valid by
construction, so "find the first valid port" collapses to "find the first port". And
`Management()` returns `(Port, bool)` comma-ok — never a `0` sentinel that smuggles
validity back in-band.

### Stage 2 — placement (R4 rung 3)

`Port`, `Ports`, `FirstNamed`, `First` say nothing about Kubernetes or Weka — they
are generic networking vocabulary, so they move to `internal/pkg/networking`
(rung 3 of `R4-helper-placement.md`). The wire adapter `ParsePorts` knows the K8s
DTO, so it stays with the feature. The feature policy stays home as a four-line
storified method:

```go
func (s kubeService) managementPort() (networking.Port, bool) {
    if p, ok := s.ports.FirstNamed(kubeWekaAPIPort); ok { return p, true }
    return s.ports.First()
}
```

Teaching point: **promote only the domain-generic parts.** The `"weka-api"` constant
is feature policy and stays in the feature — a shared package that knows one
feature's port names is not shared vocabulary, it is leaked policy.

### Stage 3 — testing contrast

Before, exercising `managementPort()` meant constructing a `kubeService` around a
full Service fixture — building a Kubernetes object to check a range predicate.
After, the logic is a leaf and its rung-0 unit tests (the composition ladder's
bottom rung — see @testing) are slice literals against `networking.Ports`; no
big-object construction:

```go
func TestPorts_FirstNamed(t *testing.T) {
    api := mustPort(t, "weka-api", 14000)
    web := mustPort(t, "http", 80)

    got, ok := networking.Ports{web, api}.FirstNamed("weka-api")

    require.True(t, ok)
    assert.Equal(t, api, got)
}

func mustPort(t *testing.T, name string, number int32) networking.Port {
    t.Helper()
    p, err := networking.ParsePort(name, number)
    require.NoError(t, err)
    return p
}
```

### The opposite failure: don't over-extract

```go
// ❌ Ceremony, not a type: no rule, no behavior — the only method unwraps.
type ReplicaCount int

func (c ReplicaCount) Int() int { return int(c) }
```

Score it against the scorecard below: no validation (+0), no meaningful methods (+0),
one call site (+0) → Score 0. Keep the `int`; if you want a name, a well-named
variable or an unexported helper in the same package is the whole answer
(`R4-helper-placement.md`, rung 1). Deep worked rejection with the cheaper
alternatives: `../examples/overabstraction-cidr.md`.

## Design guidance

A primitive should become a type when it has validation rules, has behavior attached,
represents a domain concept, is used in multiple places, or when passing an invalid
value would be a bug. When the call is not obvious, score it.

### Juiciness scoring

This scorecard lives here and only here — other rules and skills cite it, never
restate it.

**Behavioral (rich behavior):**
- Complex validation (regex, ranges, business rules): +3
- Multiple meaningful methods (≥2): +2
- State transitions/transformations: +2
- Format conversions: +1

**Structural (organizing complexity):**
- Parsing unstructured data into fields: +3
- Grouping related data that travels together: +2
- Making implicit structure explicit: +2
- Replacing `map[string]interface{}`: +2

**Usage (simplifies code):**
- Used in 5+ places: +2
- Used in 3-4 places: +1
- Significantly simplifies calling code: +1
- Makes tests cleaner: +1

**Verdict:**
- Score ≥4: HIGH priority — clear win, create the type.
- Score 2-3: MEDIUM priority — judgment call, present to the user.
- Score 0-1: LOW priority — do not create the type; that is over-engineering.

### The over-abstraction trap

The failure mode symmetric to primitive obsession is wrapping a primitive that has
nothing to own: no validation, no invariant, one method that merely unwraps. The
honest test: is `x.Field.IsSet()` *significantly* clearer than a well-named field or
accessor? If the real need is controlled mutation rather than validation or logic,
private fields with accessors beat a wrapper type. Deep worked case — the tried
extraction, the rejection rationale, and the cheaper alternatives:
`../examples/overabstraction-cidr.md`.

### Placement

A juicy type must also land in the right package — feature-scoped versus
domain-generic. That decision is `R4-helper-placement.md`; the canonical example's
Stage 2 shows it applied.

## Fix pattern

- **Replace Primitive with Domain Type**: introduce `ParseX(raw) (X, error)`
  (`R2-self-validating-types.md`); migrate call sites so raw values cross into `X`
  exactly once, at the boundary.
- **Extract Collection Type**: when logic loops over `[]primitive` or `[]DTO`, wrap
  the slice (`type Ports []Port`) and move the loop into a named query method.
- **Replace Sentinel with comma-ok**: `return 0` / `return ""` meaning
  absence/invalidity → `(X, bool)` or `(X, error)`.
- **Name enum strings**: `if status == "READY"` → `type Status string` with
  `const StatusReady Status = "READY"`.
- **Introduce Parameter Object** (Fowler): the same group of parameters traveling
  through multiple signatures (`host string, port int, useTLS bool`) becomes one
  type — that is the scorecard's "grouping related data that travels together" made
  concrete. Prefer passing the whole object over re-exploding its fields at the next
  call (Preserve Whole Object).
- **Over-abstraction found instead?** Apply the cheaper alternative — better naming,
  or private fields + accessors — per `../examples/overabstraction-cidr.md`.
- Multi-rule refactoring procedure (sequencing extraction with storifying):
  `../skills/refactoring/reference.md`. Forward design of the new types:
  @code-designing.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Does the diff validate a primitive inline instead of constructing a type?**
   Detection: `grep -nE 'if [a-zA-Z_.]+ (==|!=) ""|if [a-zA-Z_.]+ (<=?|>=?) [0-9]' $(git diff --name-only -- '*.go')`
   Violation: an emptiness/range/format check on a parameter or DTO field that names
   a domain concept (port, id, email, path, addr), outside a `ParseX`/`NewX`
   constructor.

2. **Is the same predicate enforced in more than one place?**
   Detection: for each predicate found above, grep its normalized form across the
   package, e.g. `grep -rn '> 0 && .*<= 65535' --include='*.go' .` — count hits.
   Violation: ≥2 hits — the rule has no single owner; a type is missing.

3. **Does named behavior run on a bare primitive?** Loops/switches over `[]string`,
   string-literal status comparisons, format logic on a `string` field.
   Detection: `grep -rnE '== "[A-Z_]+"' --include='*.go' .` for enum-shaped
   comparisons; inspect diff for loops whose body interprets a primitive.
   Violation: behavior attached to a bare primitive where a named method on a type
   would carry it.

4. **Does any function return a sentinel to mean "not found / invalid"?**
   Detection: grep the diff for `return 0`, `return ""`, `return -1` in functions
   whose signature has no `bool` or `error` result.
   Violation: validity encoded in-band — requires comma-ok or `(X, error)`.

5. **Do the same parameters travel together across signatures?**
   Detection: for each changed function with ≥3 parameters, grep the package for the
   same parameter-name pair/trio in other signatures, e.g.
   `grep -rnE 'func .*host string.*port int' --include='*.go' .`
   Violation: the same group of ≥2–3 parameters co-occurs in ≥2 signatures — a data
   clump; Introduce Parameter Object (score it: grouping-that-travels is +2 on the
   scorecard, plus its usage points).

6. **Inverse — is a NEW type in the diff mere ceremony?**
   Detection: count its methods (`grep -c 'func ([a-z0-9]* *\*\?<Type>)' <file>`) and
   check whether any method does more than unwrap or rename the primitive; score it
   with the scorecard above.
   Violation: Score 0-1, or the only method is `return <primitive>(x)` —
   over-abstraction; the finding must cite the cheaper alternative
   (`../examples/overabstraction-cidr.md`).
