### Before — unowned goroutine, no exit path

```go
func StartWorker(workChan <-chan Work) {
    go func() {
        for {
            work := <-workChan
            process(work)
            // No way to exit this goroutine — it outlives every caller.
        }
    }()
}
```

Three defects: the goroutine loops forever (leak — when `workChan` goes quiet it
blocks on the receive until process exit), nobody holds a handle to stop or wait for
it (fire-and-forget: `StartWorker` returns nothing), and cancellation cannot reach it
(no `ctx` — the R8 sin, one level deeper).

### After — owned, cancellable, joinable

```go
type Worker struct {
    done chan struct{}
}

// StartWorker owns the goroutine it spawns: the returned Worker can stop it
// (via ctx) and wait for it (via Wait).
func StartWorker(ctx context.Context, workChan <-chan Work) *Worker {
    w := &Worker{done: make(chan struct{})}
    go func() {
        defer close(w.done)
        for {
            select {
            case work, ok := <-workChan:
                if !ok {
                    return // channel closed — exit, don't spin on zero values
                }
                process(work)
            case <-ctx.Done():
                return // clean exit — cancellation reaches the loop
            }
        }
    }()
    return w
}

// Wait blocks until the worker's goroutine has fully exited.
func (w *Worker) Wait() { <-w.done }
```

### Second case — uncancellable backoff + unguarded shared write

Found by a real hunter pass (2026-07-07): a deploy retry loop that paces with a bare
sleep and records results in an unsynchronized package-level map.

```go
// ❌ Before
for attempt := 0; attempt < 3; attempt++ {
    resp, err := http.Post(d.endpoint+"/deploy", "application/json", bytes.NewReader(raw))
    if err != nil {
        time.Sleep(time.Duration(attempt+1) * time.Second) // cancelled caller waits anyway
        continue
    }
    // ...
    GlobalRegistry[name] = version // fatal crash if two Deploys race
}

// ✅ After — backoff selects on ctx; state owned by one guarded type
for attempt := 0; attempt < 3; attempt++ {
    resp, err := d.post(ctx, raw)
    if err != nil {
        if err := sleepCtx(ctx, backoff(attempt)); err != nil {
            return err // cancellation cuts the backoff short
        }
        continue
    }
    // ...
    d.registry.Record(name, version) // mutex lives inside Registry, next to the map
}

func sleepCtx(ctx context.Context, d time.Duration) error {
    // time.After is fine when go.mod declares go 1.23+ (the behavior is gated on
    // the module's go directive, not the toolchain): an unfired timer is
    // garbage-collected once unreferenced, so an early ctx exit does not retain it.
    select {
    case <-time.After(d):
        return nil
    case <-ctx.Done():
        return ctx.Err()
    }
}
```
