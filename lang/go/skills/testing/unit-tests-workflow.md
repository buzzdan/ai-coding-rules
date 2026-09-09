**Purpose**: Rung 0 — test leaf types in isolation, 100% coverage target

1. **Identify leaf types** - Self-contained types with logic
2. **Choose structure** - Table-driven (simple) or testify suites (complex setup)
3. **Write in pkg_test package** - Test public API only
4. **Use in-memory implementations** - From testutils or local implementations
5. **Avoid pitfalls** - No time.Sleep, no conditionals in cases, no private method tests

**Test structure:**
- Table-driven: Separate success/error test functions (complexity = 1)
- Testify suites: Only for complex infrastructure setup (HTTP servers, DBs)
- Always use named struct fields (linter reorders fields)

See reference.md for detailed patterns and examples.
