**Purpose**: Rung 0 — test leaf types in isolation, 100% coverage target

1. **Identify leaf types** - Self-contained types with logic
2. **Choose structure** - A case table (simple) or a suite/fixture (complex setup)
3. **Import as a consumer would** - Test public API only
4. **Use in-memory implementations** - From the repository's test utilities or local implementations
5. **Avoid pitfalls** - No sleeps, no conditionals in cases, no private method tests

**Test structure:**
- Case tables: Separate success/error test functions (complexity = 1)
- Suites/fixtures: Only for complex infrastructure setup (HTTP servers, DBs)
- Name every case field or parameter — positional case tuples hide what each value means

Match the repository's test framework and assertion style; never introduce a second one.