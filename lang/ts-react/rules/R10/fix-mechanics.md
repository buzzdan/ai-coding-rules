- **The moves in TypeScript + React.** Exit path: the cleanup function returned by
  the effect that started the timer, subscription or fetch — `clearInterval`,
  `unsubscribe()`, `controller.abort()`. Joinable: the promise is returned to whoever
  awaits it, or handed to `useMutation` so `isPending` and `error` are observable;
  nothing is `void`ed to hide it. Cancellable wait: `refetchInterval` on the query,
  or an interval cleared in the cleanup, in place of a `setTimeout` chain nothing
  clears. Stale state: a functional updater or a ref for the latest value; an
  `ignore` flag set in the cleanup, or an abort, for the superseded request; a
  module-level `QueryClient` becomes `useQueryClient()`.
