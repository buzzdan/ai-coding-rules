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

{{include "rules/R10/canonical-example.md"}}

## Design guidance

- **Whoever starts a goroutine owns its shutdown.** Starting a goroutine is
  acquiring a resource: the constructor/function that spawns it must hand back a way
  to stop it (a `ctx` it honors) and a way to wait for it (`Wait`/`Close`, a closed
  `done` channel, or `errgroup`). Fire-and-forget goroutines are acceptable only in
  `main`-adjacent wiring that lives as long as the process — and work that must
  legitimately outlive a request detaches honestly with `context.WithoutCancel`
  (keeps values/tracing, drops cancellation), never by manufacturing a fresh context.
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
- **Pick the right guard.** A counter or flag touched from multiple goroutines can
  be an `atomic` typed value (`atomic.Int64`, `atomic.Bool`) instead of a mutex;
  `sync.Map` only for append-only or disjoint-key caches — a plain map + mutex is
  the default (per `sync.Map`'s own doc). A mutex whose only job is one-time
  initialization is `sync.OnceFunc`/`sync.OnceValue` wearing a costume.
- **Production code does not sleep.** Backoff, pacing, and polling are
  `time.After`/`time.Ticker` inside a `select` with `ctx.Done()`; sustained rate
  limiting belongs to `golang.org/x/time/rate` (`Limiter.Wait(ctx)`). A bare
  `time.Sleep` on a cancellable path ignores cancellation by construction. (Sleeps
  in tests are `R7-test-placement.md` Q6; startup jitter in `main`-adjacent wiring
  gets the same exemption as fire-and-forget above.)
{{include "rules/R10/linter-neighbors.md"}}
- Forward design of the owning types: @code-designing. `ctx` threading discipline:
  `R8-no-globals.md`.

## Fix pattern

- **Inject the Exit Path**: add a `ctx.Done()` (or closed-channel) case to the
  goroutine's blocking loop; thread `ctx` from the caller (the Thread `ctx` move in
  `R8-no-globals.md`). For fan-out result sends, either `select` on `ctx.Done()`
  around the send or size the channel buffer to the number of senders — so no
  sender can block forever after the caller returns early.
- **Make the Goroutine Joinable**: return an owner with `Wait`/`Close`, or use
  `errgroup.Group`/`sync.WaitGroup` held by the caller — on Go 1.25+ prefer
  `wg.Go(fn)`/`g.Go(fn)` over manual `Add`/`Done` (the pairing bugs `go vet` now
  flags) — spawn and join in the same hands.
- **Extract Synchronized Owner**: move shared state plus its mutex onto one type;
  all access via methods. This proposes a new type — score it with R1's scorecard
  and expect the over-abstraction skeptic to challenge it.
- **Replace Sleep with Timer Select**: `select { case <-time.After(d): case
  <-ctx.Done(): return ctx.Err() }` — or a `time.Ticker` for polling loops.
- **Delete Unearned Guards**: a mutex on state that only one goroutine ever touches
  is ceremony — remove it (the concurrency mirror of R1's over-abstraction trap).

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

{{include "rules/R10/falsifying-questions.md"}}
