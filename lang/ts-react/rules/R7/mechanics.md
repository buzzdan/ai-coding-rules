- **Mechanics**: a `name` field on every `it.each` row and `$name` in the title so a
  failure names its case, and object rows rather than positional arrays when a row
  carries more than two values; no `setTimeout` waits — `findBy*`, `waitFor` or an
  awaited promise; `beforeEach` and `src/test-utils/` only for real infrastructure
  (the MSW server, `renderWithProviders`, a fake clock), never to hide the literal a
  test should show; import the page's public module or the hook as a consumer
  would, never a helper exported only for the test; queries by role and label
  first, `getByText` next, `getByTestId` last; success and error cases in separate
  `accepts …`/`rejects …` blocks, never one table with an `expectError` column and a
  branch on it. Tests live beside their subject (`X.test.tsx` by `X.tsx`,
  `useX.test.tsx` by `useX.ts`); `tests/` holds Playwright end-to-end specs when
  the repository has them.
