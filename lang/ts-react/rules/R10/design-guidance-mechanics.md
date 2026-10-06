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
