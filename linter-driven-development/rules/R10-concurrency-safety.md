# R10 — Concurrency Safety

## Principle

Every concurrent task has an owner and a provable exit path; shared mutable state is owned
by one type and guarded where it lives; production code never sleeps to pace or
synchronize cancellable work. Concurrency is designed at construction time — who owns
the state, who stops the concurrent task — never patched in afterward.

## Why

This rule owns exactly what static analysis cannot prove. A race detector finds
races only at runtime, only on paths a test happens to exercise; no linter can see
that a loop blocking on a receive has no way out. The failures are the worst kind:
a leaked concurrent task accumulates silently until memory or file descriptors run out; an
unsynchronized concurrent write corrupts state or **crashes the process**; a bare
sleep in a retry loop holds a cancelled request hostage for the full backoff.
Each defect also has a design meaning — a concurrent task nobody can stop has no owner
(`R2-self-validating-types.md`: construction is where ownership is established), and
state written from two concurrent tasks without a guard is the sideways-access sin of
`R8-no-globals.md` in concurrent form. The mechanical neighbors of this rule — ignored
errors, unclosed resources, copied locks — belong to the linter, not to prose. R10
hunts the residue no tool can catch.

## Canonical example

### Before — unowned concurrent task, no exit path

```text
startWorker(workQueue):
    spawn:                               # a background task nobody holds
        loop forever:
            work = workQueue.take()      # blocks; no way to exit — it outlives every caller
            process(work)
```

Three defects: the concurrent task loops forever (leak — when the queue goes quiet it
blocks on the take until process exit), nobody holds a handle to stop or wait for it
(fire-and-forget: `startWorker` returns nothing), and cancellation cannot reach it
(no cancellation signal is passed in — the R8 sin, one level deeper).

### After — owned, cancellable, joinable

```text
Worker
    done                                 # signalled when the task has fully exited
startWorker(cancel, workQueue):          # owns the task it spawns: the returned Worker
    worker = Worker()                    # can stop it (via cancel) and wait for it (via join)
    spawn:
        finally: worker.done.set()
        loop:
            wait for the first of: work = workQueue.take() | cancel is signalled | the queue is closed
            queue closed → exit          # don't spin on empty reads
            cancelled    → exit          # clean exit — cancellation reaches the loop
            process(work)
    return worker
Worker.join():
    wait for done
```

### Second case — uncancellable backoff + unguarded shared write

Found by a real hunter pass: a deploy retry loop that paces with a bare sleep and
records results in an unsynchronized module-level map.

```text
# ❌ Before
for attempt in 0..2:
    response = post(endpoint + "/deploy", payload)
    if it failed:
        sleep((attempt + 1) seconds)     # a cancelled caller waits anyway
        continue
    ...
    GlobalRegistry[name] = version       # two concurrent deploys corrupt the map, or crash

# ✅ After — the backoff waits on the timer AND the cancellation signal; state owned by one guarded type
for attempt in 0..2:
    response = self.post(cancel, payload)
    if it failed:
        if not sleepUnlessCancelled(cancel, backoff(attempt)): return cancelled
        continue
    ...
    self.registry.record(name, version)  # the lock lives inside Registry, next to the map

sleepUnlessCancelled(cancel, duration):
    wait for the first of: the timer fires | cancel is signalled
    return true when the timer fired
```

How the spawn, the cancellation signal, the join and the timed wait are spelled — a
Go `go` statement with a cancellation context and a `select`, an asyncio task with
`cancel()` and `await`, a thread with an event and `join()` — follows the
repository's concurrency model; the shape is the same in each.

## Design guidance

- **Whoever starts a concurrent task owns its shutdown.** Starting a concurrent task is
  acquiring a resource: the constructor or function that spawns it must hand back a
  way to stop it and a way to wait for it. Fire-and-forget concurrent tasks are acceptable
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
  or queue, or confine state to a single concurrent task, no lock is needed at all — reach
  for a guard only when sharing is the honest requirement.
- **Pick the right guard.** A counter or flag touched from multiple concurrent tasks can be
  an atomic value instead of a lock; a concurrent map type only for append-only or
  disjoint-key caches — a plain map plus a lock is the default. A lock whose only job
  is one-time initialization is a once-guard wearing a costume.
- **Production code does not sleep.** Backoff, pacing, and polling wait on a timer
  *and* the cancellation signal at the same time; sustained rate limiting belongs to
  a rate limiter that honors cancellation. A bare sleep on a cancellable path ignores
  cancellation by construction. (Sleeps in tests are `R7-test-placement.md` Q6;
  startup jitter in entry-point wiring gets the same exemption as fire-and-forget
  above.)
- **The linter owns the mechanical neighbors.** Ignored errors, unclosed resources,
  copied locks — enforce these in the repository's linter configuration where its
  linter has the checks; do not re-hunt them here.
- **The mechanics follow the repository's concurrency model.** Name the cancellation
  signal, the join primitive, the atomic and lock types and the timer form the
  repository already uses — an asyncio task is cancelled and awaited, a thread is
  signalled and joined, a channel worker selects on its cancellation — and never introduce a
  concurrency library the repository does not already depend on.
- Forward design of the owning types: @code-designing. Cancellation discipline:
  `R8-no-globals.md`.

## Fix pattern

- **Inject the Exit Path**: add a cancellation case to the concurrent task's blocking loop;
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
- **Delete Unearned Guards**: a lock on state that only one concurrent task ever touches
  is ceremony — remove it (the concurrency mirror of R1's over-abstraction trap).
- **The moves in the repository's language.** Use its cancellation signal for the
  exit path, its group or join primitive to make work joinable, and its timer form
  for the cancellable wait; the canonical example above shows one language's spelling.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

Build each search over the language's source files (`detected-language source`); "spawn site"
means wherever the repository starts a concurrent task — a `go` statement, a thread or
task constructor, a task-group or executor submit, an `async` job.

1. **Does every concurrent task started in the diff have a provable exit path?**
   Detection: in the changed files, find every spawn site. For each hit, read the
   concurrent task's body: a loop or a blocking take/put must wait on the cancellation
   signal (or a closed queue) at the same time, or the work must be provably bounded.
   Violation: an unbounded loop or a blocking take/put with no exit case — the
   concurrent task leaks. A loop with a non-blocking default branch is equally a
   violation: it spins at 100% CPU — block on the queue or a ticker instead.

2. **Can the code that starts a concurrent task also stop it and wait for it?**
   Detection: for each spawn site, check what the spawning function returns/exposes:
   a cancellation signal it honors plus a join/close/done handle, or a task group the
   caller holds.
   Violation: fire-and-forget in library code — no caller can join the concurrent task at
   shutdown; leaks and lost errors are invisible.

3. **Is shared mutable state written from a concurrent task without a guard?**
   Detection: for each spawned body, list writes to captured variables, receiver
   fields, and maps; cross-check that each written location is guarded — search the
   package for the language's lock, atomic and concurrent-collection types (atomic
   values and concurrent maps are legitimate guards for the state they cover) — or
   confined to a single concurrent task. Run the repository's race detector or thread
   sanitizer where it has one, but treat a quiet detector as absence of evidence,
   not evidence of absence.
   Violation: any write reachable from two concurrent tasks with no lock/queue
   ownership — for maps this can be a fatal crash, not a race that merely corrupts.

4. **Does each lock live next to the data it guards, and is the lock taken on
   every access?**
   Detection: for each lock declared in the changed files, read the declaration's
   neighbors — the guarded fields must sit in the same type, and every method
   touching them must lock; search the field names across the package for unlocked
   access paths.
   Violation: a lock guarding fields it doesn't live beside, or any access path
   that skips the lock — the guard is decorative.

5. **Does production code sleep?**
   Detection: search the changed non-test files for the language's sleep call
   (`time.Sleep`, `time.sleep`, `asyncio.sleep`, `Thread.sleep`, `setTimeout`).
   Violation: any hit on a cancellable path — backoff/pacing/polling must wait on a
   timer and the cancellation signal together, sustained pacing on a rate limiter
   that honors cancellation. A bounded loop is not exempt: a retry that sleeps three
   times on a request path still makes a stopping caller wait out every backoff; the
   count bounds the attempts, not the wait. Exempt: startup jitter in entry-point
   wiring. (Test sleeps are R7's Q6, not this rule.)

6. **Inverse — is a guard or concurrent task ceremony?**
   Detection: for each NEW lock or concurrent task in the diff, search the package for a
   second concurrent task that ever touches the guarded state, or for a caller that needed
   the work to be asynchronous.
   Violation: a lock on single-concurrent task state, or a concurrent task whose caller
   immediately blocks waiting for it — delete the ceremony; concurrency has the same
   over-abstraction trap as R1. A lock guarding only one-time initialization is the
   same finding with a named fix: the language's once-only initializer.
