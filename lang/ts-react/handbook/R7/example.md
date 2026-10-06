```typescript
// ❌ success and error fused into one table, with a branch inside the case
it.each([
  { raw: '3x100ms', expectError: false },
  { raw: '0x100ms', expectError: true },
])('parsePolicy($raw)', ({ raw, expectError }) => {
  if (expectError) {
    expect(() => parsePolicy(raw)).toThrow()
  } else {
    expect(parsePolicy(raw).maxAttempts).toBe(3)
  }
})

// ✅ two tables, one shape each, every row named
describe('parsePolicy', () => {
  it.each([
    { name: 'plain', raw: '3x100ms', maxAttempts: 3 },
    { name: 'single attempt', raw: '1x100ms', maxAttempts: 1 },
  ])('accepts $name', ({ raw, maxAttempts }) => {
    expect(parsePolicy(raw).maxAttempts).toBe(maxAttempts)
  })

  it.each([
    { name: 'zero attempts', raw: '0x100ms' },
    { name: 'missing delay', raw: '3x' },
  ])('rejects $name', ({ raw }) => {
    expect(() => parsePolicy(raw)).toThrow(PolicyError)
  })
})
```

> **In TypeScript:** a `name` field on every row and `$name` in the title, so a
> failure names its case; import as a consumer would, `from '@/retry/policy'`, never a
> symbol exported for the test. No `setTimeout` wait: `findBy*` or `waitFor`, or
> `vi.useFakeTimers` with `advanceTimersByTime`. Pages and hooks are tested through
> `renderWithProviders` over the real hook, with MSW handlers answering the fetch.
> Leaf modules, and only they, are the mutation targets where the repository
> configures Stryker: a surviving mutant is a missing row or dead logic.
