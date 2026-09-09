
1. **Does every goroutine started in the diff have a provable exit path?**
   Detection: `grep -nE '\bgo\s+[a-zA-Z_][A-Za-z0-9_.]*\(|\.Go\(' <changed files>` —
   catches `go func(...)`, method values (`go s.run()`), package-qualified calls,
   and `errgroup`/`WaitGroup` `.Go(...)` spawns. For each hit, read the goroutine
   body: a `for` loop or blocking channel op must have a `ctx.Done()`/closed-channel
   `select` case, or the work must be provably bounded.
   Violation: an unbounded loop or a blocking send/receive with no exit case — the
   goroutine leaks. A loop with a `default:` case is equally a violation: it spins
   at 100% CPU — block on the channels or a `Ticker` instead.

2. **Can the code that starts a goroutine also stop it and wait for it?**
   Detection: for each `go` site, check what the spawning function returns/exposes:
   a `ctx` it honors plus a `Wait`/`Close`/`done`-channel, or an
   `errgroup`/`WaitGroup` the caller holds.
   Violation: fire-and-forget in library code — no caller can join the goroutine at
   shutdown; leaks and lost errors are invisible.

3. **Is shared mutable state written from a goroutine without a guard?**
   Detection: for each `go func`, list writes to captured variables, receiver
   fields, and maps (`grep -n -A20 'go func' <file>`); cross-check that each written
   location is guarded — `grep -nE 'sync\.(RW)?Mutex|sync\.Map|atomic\.|chan ' <package files>`
   (atomic typed values and `sync.Map` are legitimate guards for the state they
   cover) — or confined to a single goroutine. Run `go test -race ./...` where tests exist, but
   treat a quiet race detector as absence of evidence, not evidence of absence.
   Violation: any write reachable from two goroutines with no mutex/channel
   ownership — for maps this is a fatal crash, not a race that merely corrupts.

4. **Does each mutex live next to the data it guards, and is the lock taken on
   every access?**
   Detection: `grep -nE -B1 -A5 'sync\.(RW)?Mutex' <changed files>` — the guarded
   fields must sit in the same struct, and every method touching them must lock;
   grep the field names across the package for unlocked access paths.
   Violation: a mutex guarding fields it doesn't live beside, or any access path
   that skips the lock — the guard is decorative.

5. **Does production code sleep?**
   Detection: `grep -n 'time\.Sleep' <changed files> | grep -v _test.go`
   Violation: any hit on a cancellable path — backoff/pacing/polling must be a
   timer `select` with `ctx.Done()`, sustained pacing a `rate.Limiter.Wait(ctx)`.
   Exempt: startup jitter in `main`-adjacent wiring. (Test sleeps are R7's Q6, not
   this rule.)

6. **Inverse — is a guard or goroutine ceremony?**
   Detection: for each NEW mutex or goroutine in the diff, grep the package for a
   second goroutine that ever touches the guarded state
   (`grep -rnE '\bgo\s+[a-zA-Z_][A-Za-z0-9_.]*\(|\.Go\(' <package dir>`) or for a
   caller that needed the work to be asynchronous.
   Violation: a mutex on single-goroutine state, or a goroutine whose caller
   immediately blocks waiting for it — delete the ceremony; concurrency has the same
   over-abstraction trap as R1. A mutex guarding only one-time initialization is
   the same finding with a named fix: `sync.OnceFunc`/`sync.OnceValue`.
