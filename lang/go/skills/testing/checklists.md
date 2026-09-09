<unit_tests_checklist>
- [ ] All unit tests in pkg_test package
- [ ] Testing public API only (no private methods)
- [ ] Table-driven tests use named struct fields
- [ ] No conditionals in test cases (complexity = 1)
- [ ] Using in-memory implementations from testutils
- [ ] No time.Sleep (using channels/waitgroups)
- [ ] Leaf types have 100% coverage
</unit_tests_checklist>

<integration_tests_checklist>
- [ ] Test seams between components
- [ ] Use in-memory or binary dependencies (avoid Docker)
- [ ] Build tags for optional execution (`//go:build integration`)
- [ ] Cover happy path and error scenarios across boundaries
- [ ] Real or testutils implementations (minimal mocking)
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
- [ ] Reusable mocks in internal/testutils/
- [ ] Test infrastructure has its own tests
- [ ] DSL provides readable test setup
- [ ] Can be exposed as CLI for manual testing
</test_infrastructure_checklist>

See reference.md for complete testing guidelines and examples.
