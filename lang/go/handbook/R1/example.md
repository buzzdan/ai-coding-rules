```go
// ❌ the rule lives at the call site, twice, and 0 means "none"
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

// ✅ a Port cannot exist out of range; "first valid" collapses to "first"
func ParsePort(name string, n int32) (Port, error) // the range check lives here, once
func (ps Ports) FirstNamed(name string) (Port, bool)
func (ps Ports) First() (Port, bool)
```

> **In Go:** absence is comma-ok, `(Port, bool)`; failure is `(Port, error)`. A `0`,
> `""` or `nil` returned from a plain result type is a sentinel and a finding. A
> wrapper whose only method is `func (c ReplicaCount) Int() int` scores zero on the
> scorecard: keep the `int`.
