# R10 — Concurrency Safety

## Principle

Every async task has an owner and a provable exit path; shared mutable state is owned
by one type and guarded where it lives; production code never sleeps to pace or
synchronize cancellable work. Concurrency is designed at construction time — who owns
the state, who stops the async task — never patched in afterward.

## Why

This rule owns exactly what static analysis cannot prove. A race detector finds
races only at runtime, only on paths a test happens to exercise; no linter can see
that a loop blocking on a receive has no way out. The failures are the worst kind:
a leaked async task accumulates silently until memory or file descriptors run out; an
unsynchronized concurrent write corrupts state or **crashes the process**; a bare
sleep in a retry loop holds a cancelled request hostage for the full backoff.
Each defect also has a design meaning — a async task nobody can stop has no owner
(`R2-self-validating-types.md`: construction is where ownership is established), and
state written from two async tasks without a guard is the sideways-access sin of
`R8-no-globals.md` in concurrent form. The mechanical neighbors of this rule — ignored
errors, unclosed resources, copied locks — belong to the linter, not to prose. R10
hunts the residue no tool can catch.

## Canonical example

### Before — unowned effect, no exit path

```tsx
function DeviceStatus({ id }: Readonly<{ id: DeviceId }>) {
  const [status, setStatus] = useState<Status>()

  useEffect(() => {
    setInterval(() => {
      void fetchStatus(id).then(setStatus)        // the previous fetch may land after the next
    }, POLL_MS)
    // No cleanup — the interval outlives the component.
  }, [id])

  return <StatusBadge status={status} />
}

function DevicesProvider({ children }: Readonly<{ children: ReactNode }>) {
  const [devices, setDevices] = useState<Device[]>([])
  void fetchDevices().then(setDevices)            // a fetch per render, none of them cancellable
  return <DevicesContext.Provider value={devices}>{children}</DevicesContext.Provider>
}
```

Three defects: the interval runs forever (leak — unmounting `DeviceStatus` does not
clear it, and every change of `id` starts a second one beside the first), nobody
holds a handle to stop or await the fetch (fire-and-forget: the `.then` sets state
on a component that may already be gone, and the provider starts a new request on
every render), and cancellation cannot reach it (no `AbortController`, no `signal`
— the R8 sin, one level deeper).

### After — owned, cancellable, cleaned up

```tsx
function DeviceStatus({ id }: Readonly<{ id: DeviceId }>) {
  const { data: status } = useQuery({
    queryKey: ['device-status', id],
    queryFn: ({ signal }) => fetchStatus(id, { signal }),   // the query owns the fetch and aborts it
    refetchInterval: POLL_MS,                               // and owns the polling: it stops on unmount
  })
  return <StatusBadge status={status} />
}
```

Where no query layer exists, the effect that starts the work returns the function
that stops it — the cleanup runs on unmount and before every re-run:

```tsx
useEffect(() => {
  const controller = new AbortController()
  const timer = setInterval(() => {
    void refreshStatus(id, controller.signal).then(setStatus).catch(ignoreAbort)
  }, POLL_MS)
  return () => {                                  // whoever starts the timer owns its stop
    clearInterval(timer)
    controller.abort()
  }
}, [id])
```

A promise whose handle is dropped — `void fetchDevices()` with nothing holding a
`signal` — is the effect-free form of the Before: nobody can cancel it, nobody sees
its rejection, and its `.then` writes state whenever it pleases.

### Second case — out-of-order response + stale closure

Found by a real hunter pass: a search box whose results flicker back to an older
query, and a counter that stops at 1.

```tsx
// ❌ Before
useEffect(() => {
  void searchDevices(query).then(setResults)      // two in-flight searches; the slower one wins
}, [query])

useEffect(() => {
  const timer = setInterval(() => setCount(count + 1), 1000)   // `count` frozen at the first render
  return () => clearInterval(timer)
}, [])

// ✅ After — the cleanup retires the superseded request; the updater reads the latest value
useEffect(() => {
  let ignore = false
  void searchDevices(query).then((found) => {
    if (!ignore) setResults(found)
  })
  return () => {
    ignore = true                                 // a response to a query nobody wants any more is dropped
  }
}, [query])

useEffect(() => {
  const timer = setInterval(() => setCount((n) => n + 1), 1000)
  return () => clearInterval(timer)
}, [])
```

Where `searchDevices` takes a `signal`, an `AbortController` whose `abort()` is the
cleanup replaces the `ignore` flag and also stops the network request. In a
repository with TanStack Query both halves of the first case disappear:
`useQuery({ queryKey: ['search', query], … })` keys each request by its input,
drops the superseded one, and never needs a second signal.

## Design guidance

- **Whoever starts a async task owns its shutdown.** Starting a async task is
  acquiring a resource: the constructor or function that spawns it must hand back a
  way to stop it and a way to wait for it. Fire-and-forget async tasks are acceptable
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
  or queue, or confine state to a single async task, no lock is needed at all — reach
  for a guard only when sharing is the honest requirement.
- **Pick the right guard.** A counter or flag touched from multiple async tasks can be
  an atomic value instead of a lock; a concurrent map type only for append-only or
  disjoint-key caches — a plain map plus a lock is the default. A lock whose only job
  is one-time initialization is a once-guard wearing a costume.
- **Production code does not sleep.** Backoff, pacing, and polling wait on a timer
  *and* the cancellation signal at the same time; sustained rate limiting belongs to
  a rate limiter that honors cancellation. A bare sleep on a cancellable path ignores
  cancellation by construction. (Sleeps in tests are `R7-test-placement.md` Q6;
  startup jitter in entry-point wiring gets the same exemption as fire-and-forget
  above.)
- **The linter owns the mechanical neighbors.** Unawaited promises
  (`@typescript-eslint/no-floating-promises`), a promise where a callback is expected
  (`@typescript-eslint/no-misused-promises`), a chain with no `catch`
  (`promise/catch-or-return`), a missing effect dependency (`react-hooks/exhaustive-deps`),
  state set synchronously in an effect (`react-hooks/set-state-in-effect`) — enforce
  these in `eslint.config.*`; do not re-hunt them here. There is no race detector: an
  out-of-order response is found by reading the code.
- **The mechanics in TypeScript + React.** Effects: the function passed to
  `useEffect` returns the cleanup that undoes what it started — `clearInterval`,
  `clearTimeout`, `removeEventListener`, `unsubscribe()`, `socket.close()`,
  `controller.abort()`; React runs the cleanup on unmount and before every re-run,
  so it is also the exit path when a dependency changes. The effect callback is
  never `async` (it would return a promise where React expects a cleanup); the
  async work lives in an inner function or a `.then`. Fetches: an `AbortController`
  created by the effect that owns the fetch, its `signal` threaded through the
  service to `fetch`, its `AbortError` ignored by that owner; in a repository with
  TanStack Query the query owns the lifecycle — `queryFn: ({ signal }) => …`,
  `refetchInterval` for polling, `useMutation` for writes — and a raw fetch in an
  effect is the finding. There is one thread, so there are no locks and no atomics;
  the hazards are ordering and leaks: a stale closure reads the render's value, not
  the latest — a functional `setState((prev) => …)` or a `useRef` holding the latest
  value is the fix; an out-of-order response is dropped by an `ignore` flag set in
  the cleanup or by aborting the superseded request. The dependency array is a
  contract, not a tuning knob: a disabled `react-hooks/exhaustive-deps` is a
  suppression of this rule.
- Forward design of the owning types: @code-designing. Cancellation discipline:
  `R8-no-globals.md`.

## Fix pattern

- **Inject the Exit Path**: add a cancellation case to the async task's blocking loop;
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
- **Delete Unearned Guards**: a lock on state that only one async task ever touches
  is ceremony — remove it (the concurrency mirror of R1's over-abstraction trap).
- **The moves in TypeScript + React.** Exit path: the cleanup returned by the effect
  that started the timer, subscription or fetch — `clearInterval`, `unsubscribe()`,
  `controller.abort()`. Joinable: the promise returned to whoever awaits it, or handed
  to `useMutation` so `isPending` and `error` are observable; nothing `void`ed to hide
  it. Cancellable wait: `refetchInterval` on the query, or an interval cleared in the
  cleanup, in place of a `setTimeout` chain nothing clears. Stale state: a functional
  updater or a ref; an `ignore` flag or an abort retires the superseded request.

## Falsifying questions

Answer each with evidence (`file:line`, command output) — never a bare verdict.

Build each search over `*.ts` and `*.tsx` files outside `node_modules`; "start
site" means wherever the repository starts a timer, a subscription, a socket or a
fetch — in an effect, a custom hook, an event handler or a service.

1. **Does every timer, subscription or fetch started in the diff have a provable exit path?**
   Detection: `grep -nE 'setInterval\(|setTimeout\(|addEventListener\(|\.subscribe\(|\.observe\(|new WebSocket\(|new EventSource\(' <changed files>` —
   catches timers, DOM and store subscriptions, observers and long-lived
   connections. For each hit inside a `useEffect` or a custom hook, read the effect:
   it must return a cleanup that calls the matching `clearInterval`/`clearTimeout`/
   `removeEventListener`/`unsubscribe()`/`disconnect()`/`close()`, or the work must
   be provably bounded (a one-shot `setTimeout` whose callback touches no state).
   Violation: a started timer, listener, socket or observer with no cleanup — it
   outlives the component, and every change of a dependency starts a second one
   beside the first. A `useEffect` under a disabled `react-hooks/exhaustive-deps`
   is equally a violation: the effect re-runs on the wrong schedule, and the
   cleanup, when there is one, no longer matches what was started.

2. **Can the code that starts a fetch or a promise also stop it and wait for it?**
   Detection: for each start site, check what the starter holds: an
   `AbortController` whose `abort()` runs in the cleanup, a promise returned to its
   caller or to `useMutation`, a `queryFn` that takes `{ signal }`.
   `grep -nE '\bvoid [a-zA-Z_.]+\(|\.then\(' <changed files>` lists the chains
   nobody awaits; `@typescript-eslint/no-floating-promises` marks the bare ones.
   Violation: fire-and-forget in library code — a fetch in an effect with no
   `AbortController`, a promise chain nobody awaits, a `void somePromise()` that
   hides the leak instead of owning it — no caller can cancel or observe it, and its
   rejection surfaces as an unhandled-rejection log line, not as handling. A raw
   fetch in `useEffect` in a repository that has TanStack Query is the finding even
   with a controller: the query layer owns the lifecycle (`queryFn({ signal })`).

3. **Is shared mutable state written from two async continuations without a guard?**
   Detection: for each effect or handler with an `await` or a `.then`, list what the
   continuation writes — `setX(…)` calls, `ref.current = …`, a module-level
   `Map`/array/object (`grep -n -A15 'useEffect(\|\.then(\|await ' <file>`);
   cross-check that a second continuation can reach the same state: the same effect
   re-run after a dependency change while the first request is in flight, two
   effects setting one state, a handler the user can fire twice. There is no race
   detector and no lock: the guard is an `ignore` flag set in the cleanup, an abort
   of the superseded request, or the query layer's keying by `queryKey`.
   Violation: any write reachable from two continuations with no such guard — the
   out-of-order response (the older request resolves last and wins), two effects
   writing one state, a module-level cache mutated from async code.

4. **Does each guard live next to the data it guards, and is the guard checked on
   every access?**
   Detection: `grep -nE 'isFetching|inFlight|isLoading|pending|\.current\b' <changed files>` —
   for each flag or ref used as a guard (`if (inFlightRef.current) return`), check
   that the test and the write it protects sit in the same synchronous span: no
   `await` between them, both in the same hook or module, every writer going
   through the same check.
   Violation: check-then-act across an `await` on a ref or on module state (two
   calls pass the check before either sets it), or a flag set in one module and
   read in another — the guard is decorative. The query layer's `isFetching` is
   read by the component, never written; a hand-rolled one beside it is this
   finding.

5. **Does production code sleep?**
   Detection: `grep -nE 'setTimeout\(|new Promise\([^)]*setTimeout' <changed files> | grep -v '\.test\.'`
   Violation: a `setTimeout` chain used for polling or backoff that no cleanup
   clears, or an `await new Promise((resolve) => setTimeout(resolve, d))` in a retry
   loop with no `signal` to cut it short — a user who navigated away keeps the
   polling alive. The cancellable forms: `refetchInterval` and `retryDelay` on the
   query, an interval cleared in the effect's cleanup, a sleep that rejects when its
   `signal` aborts. Exempt: a one-shot UI delay (a toast's dismissal) whose timer the
   cleanup clears. (Test waits are R7's Q6, not this rule.)

6. **Inverse — is a guard, ref or effect ceremony?**
   Detection: for each NEW `AbortController`, `useRef`, effect or hand-rolled cache
   in the diff, check what it guards: a second in-flight request that can actually
   happen, a value that actually changes between renders, a fetch the query layer
   does not already own.
   Violation: a `useRef` latest-value dance where listing the dependency would do;
   a manual cache or in-flight map beside TanStack Query; an effect that copies a
   prop into state (`react-hooks/set-state-in-effect` marks it) where a value
   derived during render would do — delete the ceremony; concurrency has the same
   over-abstraction trap as R1. An `AbortController` on a fetch whose component
   never unmounts before it resolves is not this finding: the guard costs one line
   and the failure it prevents is silent.
