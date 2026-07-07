# R10 — Concurrency Safety

## Principle

Every goroutine has an owner and a provable exit path; shared mutable state is owned
by one type and guarded where it lives; production code never sleeps to pace or
synchronize cancellable work. Concurrency is designed at construction time — who owns
the state, who stops the goroutine — never patched in afterward.

## Why

This rule owns exactly what static analysis cannot prove. The race detector finds
races only at runtime, only on paths a test happens to exercise; no linter can see
that a `for { <-ch }` goroutine has no way out. The failures are the worst kind:
a leaked goroutine accumulates silently until memory or file descriptors run out; an
unsynchronized concurrent map write is a **fatal runtime crash**, not an error; a bare
`time.Sleep` in a retry loop holds a cancelled request hostage for the full backoff.
Each defect also has a design meaning — a goroutine nobody can stop has no owner
(`R2-self-validating-types.md`: construction is where ownership is established), and
state written from two goroutines without a guard is the sideways-access sin of
`R8-no-globals.md` in concurrent form. The mechanical neighbors of this rule belong to
the linter, not to prose: `errcheck` owns ignored errors, `bodyclose` owns unclosed
bodies, `govet copylocks` owns copied locks. R10 hunts the residue no tool can catch.

## Canonical example

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
            case work := <-workChan:
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
    select {
    case <-time.After(d):
        return nil
    case <-ctx.Done():
        return ctx.Err()
    }
}
```

## Design guidance

- **Whoever starts a goroutine owns its shutdown.** Starting a goroutine is
  acquiring a resource: the constructor/function that spawns it must hand back a way
  to stop it (a `ctx` it honors) and a way to wait for it (`Wait`/`Close`, a closed
  `done` channel, or `errgroup`). Fire-and-forget goroutines are acceptable only in
  `main`-adjacent wiring that lives as long as the process.
- **Every blocking loop selects on its exit.** A `for` loop containing a channel
  receive, send, or sleep gets a `select` with a `ctx.Done()` (or closed-channel)
  case. A blocking operation with no exit case is a leak with a delay on it.
- **State and its guard are one unit.** Shared mutable state lives on one type with
  the mutex declared directly above the fields it guards, and every access goes
  through that type's methods. A mutex in one place guarding data in another is a
  convention, not a guarantee. (Whether that type is worth extracting is R1's
  scorecard; that it must not be a package global is R8.)
- **Prefer handing off to sharing.** If the design can pass values through a channel
  or confine state to a single goroutine, no mutex is needed at all — reach for a
  guard only when sharing is the honest requirement.
- **Production code does not sleep.** Backoff, pacing, and polling are
  `time.After`/`time.Ticker` inside a `select` with `ctx.Done()`. A bare
  `time.Sleep` on a cancellable path ignores cancellation by construction. (Sleeps
  in tests are `R7-test-placement.md` Q6.)
- **The linter owns the mechanical neighbors.** Ignored errors (`errcheck`),
  unclosed response bodies (`bodyclose`), copied locks (`govet copylocks`) — enforce
  these in `.golangci.yaml`; do not re-hunt them here.
- Forward design of the owning types: @code-designing. `ctx` threading discipline:
  `R8-no-globals.md`.

## Fix pattern

- **Inject the Exit Path**: add a `ctx.Done()` (or closed-channel) case to the
  goroutine's blocking loop; thread `ctx` from the caller (the Thread `ctx` move in
  `R8-no-globals.md`).
- **Make the Goroutine Joinable**: return an owner with `Wait`/`Close`, or use
  `errgroup.Group`/`sync.WaitGroup` held by the caller — spawn and join in the same
  hands.
- **Extract Synchronized Owner**: move shared state plus its mutex onto one type;
  all access via methods. This proposes a new type — score it with R1's scorecard
  and expect the over-abstraction skeptic to challenge it.
- **Replace Sleep with Timer Select**: `select { case <-time.After(d): case
  <-ctx.Done(): return ctx.Err() }` — or a `time.Ticker` for polling loops.
- **Delete Unearned Guards**: a mutex on state that only one goroutine ever touches
  is ceremony — remove it (the concurrency mirror of R1's over-abstraction trap).

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

1. **Does every goroutine started in the diff have a provable exit path?**
   Detection: `grep -nE 'go func|go [a-zA-Z_]+\(' <changed files>` — for each hit,
   read the goroutine body: a `for` loop or blocking channel op must have a
   `ctx.Done()`/closed-channel `select` case, or the work must be provably bounded.
   Violation: an unbounded loop or a blocking send/receive with no exit case — the
   goroutine leaks.

2. **Can the code that starts a goroutine also stop it and wait for it?**
   Detection: for each `go` site, check what the spawning function returns/exposes:
   a `ctx` it honors plus a `Wait`/`Close`/`done`-channel, or an
   `errgroup`/`WaitGroup` the caller holds.
   Violation: fire-and-forget in library code — no caller can join the goroutine at
   shutdown; leaks and lost errors are invisible.

3. **Is shared mutable state written from a goroutine without a guard?**
   Detection: for each `go func`, list writes to captured variables, receiver
   fields, and maps (`grep -n -A20 'go func' <file>`); cross-check that each written
   location is guarded — `grep -n 'sync\.(RW)?Mutex|chan ' <package files>` — or
   confined to a single goroutine. Run `go test -race ./...` where tests exist, but
   treat a quiet race detector as absence of evidence, not evidence of absence.
   Violation: any write reachable from two goroutines with no mutex/channel
   ownership — for maps this is a fatal crash, not a race that merely corrupts.

4. **Does each mutex live next to the data it guards, and is the lock taken on
   every access?**
   Detection: `grep -n -B1 -A5 'sync\.(RW)?Mutex' <changed files>` — the guarded
   fields must sit in the same struct, and every method touching them must lock;
   grep the field names across the package for unlocked access paths.
   Violation: a mutex guarding fields it doesn't live beside, or any access path
   that skips the lock — the guard is decorative.

5. **Does production code sleep?**
   Detection: `grep -rn 'time\.Sleep' --include='*.go' . | grep -v _test.go`
   Violation: any hit on a cancellable path — backoff/pacing/polling must be a
   timer `select` with `ctx.Done()`. (Test sleeps are R7's Q6, not this rule.)

6. **Inverse — is a guard or goroutine ceremony?**
   Detection: for each NEW mutex or goroutine in the diff, grep the package for a
   second goroutine that ever touches the guarded state (`grep -n 'go func\|go [a-zA-Z_]+\(' .`)
   or for a caller that needed the work to be asynchronous.
   Violation: a mutex on single-goroutine state, or a goroutine whose caller
   immediately blocks waiting for it — delete the ceremony; concurrency has the same
   over-abstraction trap as R1.
