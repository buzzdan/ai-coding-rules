```go
// ❌ no owner, no exit, paced by sleep
go func() {
    for {
        poll()
        time.Sleep(interval)
    }
}()

// ✅ the type that starts it stops it; the wait is cancellable
func (p *Poller) Run(ctx context.Context) error {
    t := time.NewTicker(p.interval)
    defer t.Stop()
    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-t.C:
            p.poll(ctx)
        }
    }
}
```

> **In Go:** a goroutine is started with the `ctx` that will stop it and joined with an
> `errgroup` or a `sync.WaitGroup`; a `time.Sleep` in production code is a
> `select` on a timer and `ctx.Done()`. A mutex sits in the struct beside the fields
> it guards, and a guard around fields only one goroutine touches is deleted.
