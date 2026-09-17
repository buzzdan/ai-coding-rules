<unit_tests_checklist>
- [ ] All unit tests import the code as a consumer would
- [ ] Testing public API only (no private methods)
- [ ] Case tables name every field or parameter
- [ ] No conditionals in test cases (complexity = 1)
- [ ] Using in-memory implementations from the repository's test utilities
- [ ] No sleeps (events, channels or futures with a timeout)
- [ ] Leaf types have 100% coverage
</unit_tests_checklist>

<integration_tests_checklist>
- [ ] Test seams between components
- [ ] Use in-memory or binary dependencies (avoid Docker)
- [ ] Marked for optional execution the way the repository marks slow tests
- [ ] Cover happy path and error scenarios across boundaries
- [ ] Real or test-utility implementations (minimal mocking)
</integration_tests_checklist>

<system_tests_checklist>
- [ ] Located in tests/ folder at project root
- [ ] Black box testing via CLI/API
- [ ] Appropriate dependency level chosen (in-memory, binary, or test-containers)
- [ ] Tests critical end-to-end workflows
- [ ] Dependencies documented (what's needed to run tests)
- [ ] CI-compatible (either fast in-memory or containerized setup)
</system_tests_checklist>

<test_infrastructure_checklist>
- [ ] Reusable fakes live where the repository keeps its test utilities
- [ ] Test infrastructure has its own tests
- [ ] DSL provides readable test setup
- [ ] Can be exposed as CLI for manual testing
</test_infrastructure_checklist>

The repository's own test framework and utilities are the reference for how each
item is spelled.