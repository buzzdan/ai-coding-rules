- **The mechanics in Go.** Stop with a `ctx` the goroutine honors; wait with
  `Wait`/`Close`, a closed `done` channel, or `errgroup`; detach with
  `context.WithoutCancel` (keeps values/tracing, drops cancellation). Every blocking
  loop gets a `select` with a `ctx.Done()` (or closed-channel) case. Counters and
  flags: `atomic.Int64`, `atomic.Bool`. `sync.Map` only for append-only or
  disjoint-key caches (per `sync.Map`'s own doc); one-time initialization is
  `sync.OnceFunc`/`sync.OnceValue`. Backoff and polling: `time.After`/`time.Ticker`
  inside a `select` with `ctx.Done()`; rate limiting: `golang.org/x/time/rate`
  (`Limiter.Wait(ctx)`), never a bare `time.Sleep`.
