MSW handlers answering the real `fetch` (never a `vi.mock` of the service module),
an in-memory `PreferencesStore` with the production store's methods, `vi.useFakeTimers()` for the clock
