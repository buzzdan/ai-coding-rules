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
