- **The moves in TypeScript + React.** Exit path: the cleanup returned by the effect
  that started the timer, subscription or fetch — `clearInterval`, `unsubscribe()`,
  `controller.abort()`. Joinable: the promise returned to whoever awaits it, or handed
  to `useMutation` so `isPending` and `error` are observable; nothing `void`ed to hide
  it. Cancellable wait: `refetchInterval` on the query, or an interval cleared in the
  cleanup, in place of a `setTimeout` chain nothing clears. Stale state: a functional
  updater or a ref; an `ignore` flag or an abort retires the superseded request.
