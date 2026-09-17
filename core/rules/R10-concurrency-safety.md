# R10 — Concurrency Safety

## Principle

Every {{.Task}} has an owner and a provable exit path; shared mutable state is owned
by one type and guarded where it lives; production code never sleeps to pace or
synchronize cancellable work. Concurrency is designed at construction time — who owns
the state, who stops the {{.Task}} — never patched in afterward.

## Why

This rule owns exactly what static analysis cannot prove. A race detector finds
races only at runtime, only on paths a test happens to exercise; no linter can see
that a loop blocking on a receive has no way out. The failures are the worst kind:
a leaked {{.Task}} accumulates silently until memory or file descriptors run out; an
unsynchronized concurrent write corrupts state or **crashes the process**; a bare
sleep in a retry loop holds a cancelled request hostage for the full backoff.
Each defect also has a design meaning — a {{.Task}} nobody can stop has no owner
(`R2-self-validating-types.md`: construction is where ownership is established), and
state written from two {{.Task}}s without a guard is the sideways-access sin of
`R8-no-globals.md` in concurrent form. The mechanical neighbors of this rule — ignored
errors, unclosed resources, copied locks — belong to the linter, not to prose. R10
hunts the residue no tool can catch.

## Canonical example

{{include "rules/R10/canonical-example.md"}}

## Design guidance

- **Whoever starts a {{.Task}} owns its shutdown.** Starting a {{.Task}} is
  acquiring a resource: the constructor or function that spawns it must hand back a
  way to stop it and a way to wait for it. Fire-and-forget {{.Task}}s are acceptable
  only in entry-point wiring that lives as long as the process — and work that must
  legitimately outlive a request detaches honestly, keeping the request's values and
  tracing while dropping its cancellation, never by manufacturing a fresh root context.
- **Every blocking loop selects on its exit.** A loop that blocks on a receive, a
  send or a sleep also waits on its cancellation signal. A blocking operation with no
  exit case is a leak with a delay on it.
- **State and its guard are one unit.** Shared mutable state lives on one type with
  the lock declared directly above the fields it guards, and every access goes
  through that type's methods. A lock in one place guarding data in another is a
  convention, not a guarantee. (Whether that type is worth extracting is R1's
  scorecard; that it must not be a package global is R8.)
- **Prefer handing off to sharing.** If the design can pass values through a channel
  or queue, or confine state to a single {{.Task}}, no lock is needed at all — reach
  for a guard only when sharing is the honest requirement.
- **Pick the right guard.** A counter or flag touched from multiple {{.Task}}s can be
  an atomic value instead of a lock; a concurrent map type only for append-only or
  disjoint-key caches — a plain map plus a lock is the default. A lock whose only job
  is one-time initialization is a once-guard wearing a costume.
- **Production code does not sleep.** Backoff, pacing, and polling wait on a timer
  *and* the cancellation signal at the same time; sustained rate limiting belongs to
  a rate limiter that honors cancellation. A bare sleep on a cancellable path ignores
  cancellation by construction. (Sleeps in tests are `R7-test-placement.md` Q6;
  startup jitter in entry-point wiring gets the same exemption as fire-and-forget
  above.)
{{include "rules/R10/linter-neighbors.md"}}
{{include "rules/R10/design-guidance-mechanics.md"}}
- Forward design of the owning types: @code-designing. Cancellation discipline:
  `R8-no-globals.md`.

## Fix pattern

- **Inject the Exit Path**: add a cancellation case to the {{.Task}}'s blocking loop;
  pass cancellation from the caller (the Pass Cancellation Down move in
  `R8-no-globals.md`). For fan-out result sends, either wait on cancellation around
  the send or size the channel buffer to the number of senders — so no sender can
  block forever after the caller returns early.
- **Make Concurrent Work Joinable**: return an owner with `Wait`/`Close`, or use a
  group the caller holds — spawn and join in the same hands.
- **Extract Synchronized Owner**: move shared state plus its lock onto one type;
  all access via methods. This proposes a new type — score it with R1's scorecard
  and expect the over-abstraction skeptic to challenge it.
- **Replace Sleep with Cancellable Wait**: wait on a timer and the cancellation
  signal together — or a ticker for polling loops.
- **Delete Unearned Guards**: a lock on state that only one {{.Task}} ever touches
  is ceremony — remove it (the concurrency mirror of R1's over-abstraction trap).
{{include "rules/R10/fix-mechanics.md"}}

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

{{include "rules/R10/falsifying-questions.md"}}
