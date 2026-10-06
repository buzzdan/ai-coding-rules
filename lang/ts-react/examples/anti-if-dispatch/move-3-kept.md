```typescript
export function severityColor(s: Severity): string {
  switch (s) {
    case 'info':
      return 'blue'
    case 'warning':
      return 'yellow'
    case 'critical':
      return 'red'
    default:
      return assertNever(s) // exhaustive: tsc fails when a Severity is added unhandled
  }
}
```

The `default: return assertNever(s)` arm is not an unknown-kind default — it is the
completeness proof. `tsc` narrows `s` through the arms; if a member is left
unhandled, the type reaching `assertNever` (`(x: never) => never`, the one-line
helper every TypeScript codebase carries) is not `never` and the typecheck fails at
this `switch`. Adding `'fatal'` to `Severity` now fails `tsc` instead of falling
through to `''`. That is the whole benefit, at none of the cost.
(`@typescript-eslint/switch-exhaustiveness-check` says the same when it is
configured; without it or the `assertNever` arm, a `switch` with a fall-through after
it is incomplete silently.)
