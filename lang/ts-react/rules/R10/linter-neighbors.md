- **The linter owns the mechanical neighbors.** Unawaited promises
  (`@typescript-eslint/no-floating-promises`), a promise handed where a plain
  callback is expected (`@typescript-eslint/no-misused-promises`), a chain with no
  `catch` (`promise/catch-or-return`), an effect missing a dependency it reads
  (`react-hooks/exhaustive-deps`), state set synchronously in an effect body
  (`react-hooks/set-state-in-effect`) — enforce these in `eslint.config.*`; do not
  re-hunt them here. There is no race detector: an out-of-order response is found
  by reading the code.
