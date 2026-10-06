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

// ❌ a shape crosses the boundary; the caller pokes the method out of it
func bearerToken(headers map[string]string) (string, bool) {
    for name, value := range headers {
        if name == "Authorization" && strings.HasPrefix(value, "Bearer ") {
            return strings.TrimPrefix(value, "Bearer "), true
        }
    }
    return "", false
}

// ✅ the container has a name, and the loop is its method
type Headers struct{ raw map[string]string } // the constructor copies the map in

func (h Headers) AuthToken() (string, bool) {
    value, ok := h.raw["Authorization"]
    if !ok || !strings.HasPrefix(value, "Bearer ") {
        return "", false
    }
    return strings.TrimPrefix(value, "Bearer "), true
}
```

> **In Go:** absence is comma-ok, `(Port, bool)`; failure is `(Port, error)`. A `0`,
> `""` or `nil` returned from a plain result type is a sentinel and a finding. A
> wrapper whose only method is `func (c ReplicaCount) Int() int` scores zero on the
> scorecard: keep the `int`. A `map[string]string` or `[]string` crossing a function
> boundary is a shape, not a concept: read what the receivers do with it, and name the
> type. A nested type (`map[string]map[string]int`, `map[string][]string`) is always a
> missing named type; `[]byte` and `map[string]struct{}` are one level, not nesting.
