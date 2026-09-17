1. **Find the lowest rung** that contains the behavior (see composition_ladder)
2. **Choose structure**: a case table for simple behaviors (the repository's
   table-test or parametrize idiom), a suite or fixture for complex setup
3. **Import as a consumer would** - test public API only
4. **Compose real layers** - in-memory/in-process implementations from the
   repository's test utilities
5. **Avoid pitfalls**: No sleeps, no conditionals in test cases

Ready after tests? Run the repository's lint command with its fix flag.