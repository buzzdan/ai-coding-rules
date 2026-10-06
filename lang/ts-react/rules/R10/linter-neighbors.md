- **The linter owns the mechanical neighbors.** Unawaited promises
  (`@typescript-eslint/no-floating-promises`), a promise where a callback is expected
  (`@typescript-eslint/no-misused-promises`), a chain with no `catch`
  (`promise/catch-or-return`), a missing effect dependency (`react-hooks/exhaustive-deps`),
  state set synchronously in an effect (`react-hooks/set-state-in-effect`) — enforce
  these in `eslint.config.*`; do not re-hunt them here. There is no race detector: an
  out-of-order response is found by reading the code.
