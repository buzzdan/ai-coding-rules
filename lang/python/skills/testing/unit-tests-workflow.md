**Purpose**: Rung 0 — test leaf types in isolation, 100% coverage target

1. **Identify leaf types** - Self-contained types with logic
2. **Choose structure** - `@pytest.mark.parametrize` (simple) or fixture-backed setup (complex infrastructure)
3. **Import as a consumer would** - `from app import user`; never a `_private` name
4. **Use in-memory implementations** - From the repository's test-support package or local implementations
5. **Avoid pitfalls** - No `time.sleep`, no conditionals in test bodies, no `_private` tests, no `mock.patch` of collaborators

**Test structure:**
- Parametrized: Separate success/error test functions (complexity = 1)
- Fixtures: Only for real infrastructure (`tmp_path`, a fake server, a database) — never to hide the literal a test should show
- `pytest.param(..., id=...)` on every row; named fields when a row carries more than two values

See reference.md for detailed patterns and examples.
