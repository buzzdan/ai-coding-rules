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
   `items.forEach(async (item) => …)` is the loop form: one promise per item that
   nothing awaits, so a rejection vanishes (`@typescript-eslint/no-misused-promises`
   marks the callback where it is configured). Sequential work is `for (const item
   of items) { await … }`; independent work is `await Promise.all(items.map(…))` —
   the finding is the `forEach`, the fix is whichever of the two the caller means.

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
