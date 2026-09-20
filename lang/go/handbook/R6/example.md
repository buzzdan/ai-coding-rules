```go
// ❌ one implementer in production; the interface exists for the mock in the test
type DeviceStore interface {
    Get(ctx context.Context, id DeviceID) (Device, error)
}

func NewFleet(store DeviceStore) *Fleet

// ✅ depend on the concrete type; the test wires a real store over an embedded database
func NewFleet(store *sqlite.DeviceStore) *Fleet
```

> **In Go:** an interface is earned by a second production implementation or a
> verified import cycle, and it stays small: one or two methods, `io.Reader`-sized. A
> hand-written struct that satisfies a production interface only in a `_test.go` file
> is a mock, whatever it is called.
