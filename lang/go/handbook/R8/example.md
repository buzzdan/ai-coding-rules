```go
// ❌ reached sideways from three layers; untestable without the environment
var cfg = config.MustLoad()

func (f *Fleet) Record(hb Heartbeat) error {
    if cfg.ReadOnly { /* ... */ }
}

// ✅ read once in main, pushed down as a value
func main() {
    cfg := config.MustLoad()
    fleet := device.NewFleet(store, cfg.Fleet)
}
```

> **In Go:** `ctx` is the first parameter of every function that does I/O and is passed
> from caller to callee; `context.Background()` belongs in `main` and in tests only.
> An `init()` that writes state is import-time initialization: replace it with a
> constructor.
