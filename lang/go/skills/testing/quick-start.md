1. **Find the lowest rung** that contains the behavior (see composition_ladder)
2. **Choose structure**: table-driven (simple) or testify suites (complex setup)
3. **Write in pkg_test package** - test public API only
4. **Compose real layers** - in-memory/in-process implementations from testutils
5. **Avoid pitfalls**: No time.Sleep, no conditionals in test cases

Ready after tests? Run linter: `task lintwithfix`
