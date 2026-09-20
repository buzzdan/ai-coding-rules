```go
// ❌ one implementer in production; the interface exists for the mock in the test
type DeviceStore interface {
    Get(ctx context.Context, id DeviceID) (Device, error)
}

func NewFleet(store DeviceStore, cfg FleetConfig) *Fleet

// ✅ depend on the concrete type; the test wires a real store over an embedded database
func NewFleet(store *sqlite.DeviceStore, cfg FleetConfig) *Fleet
```

> **In Go:** an earned interface stays small and cohesive, `io.Reader`-sized. A
> hand-written struct that satisfies a production interface only in a `_test.go` file
> is a mock, whatever it is called.
