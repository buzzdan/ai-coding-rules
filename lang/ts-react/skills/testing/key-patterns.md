**Parametrized Tests (Cyclomatic Complexity = 1):**
- **NEVER add an `expectError` column** - It splits test logic and puts `if (expectError)` in the body
- **Max complexity = 1 inside a test body** - No if/else, no switch, no ternary, no `?.` guarding an assertion
- Separate success and error `it`s (`it.each(valid)('parses $name', ...)`, `it.each(invalid)('rejects $name', ...)`)
- A `name` on every `it.each` row; object rows (`{ name, raw, want }`) when a case carries more than two values
- Canonical violation, detection commands, and split pattern: `../../rules/R7-test-placement.md`; worked example in reference.md

**Rendering and queries:**
- `renderWithProviders` for anything that reads the query client or the router; plain `render` for a leaf component
- `screen.getByRole`/`getByLabelText` first, `getByText` next, `getByTestId` last; `queryBy*` only to assert absence
- `const user = userEvent.setup()` then `await user.click(...)`, never `fireEvent`
- `server.use(handler)` for a per-test override (reset by `afterEach` in `setup.ts`); hooks through `renderHook` with the providers `wrapper`
- `act` only around what RTL does not already wrap (advancing fake timers, a manual store update)

**Synchronization:**
- Never wait on `setTimeout` (flaky, slow)
- `await screen.findBy*(...)` or `await waitFor(() => expect(...))` for anything async; `vi.useFakeTimers()` + `await vi.advanceTimersByTimeAsync(ms)` for debounce and polling
- Every promise the test started is awaited before asserting; `vi.useRealTimers()` in `afterEach`

See reference.md for complete patterns with code examples.
