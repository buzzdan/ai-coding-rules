- **The moves in Go.** Exit path: a `select` case on `<-ctx.Done()`, `ctx` threaded
  from the caller. Joinable: `errgroup.Group`/`sync.WaitGroup` held by the caller —
  on Go 1.25+ prefer `wg.Go(fn)`/`g.Go(fn)` over manual `Add`/`Done` (the pairing
  bugs `go vet` now flags). Cancellable wait: `select { case <-time.After(d): case
  <-ctx.Done(): return ctx.Err() }`, or a `time.Ticker` for polling loops.
