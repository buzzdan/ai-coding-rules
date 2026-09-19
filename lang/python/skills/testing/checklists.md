<unit_tests_checklist>
- [ ] All unit tests import the package as a consumer would (`from app import user`)
- [ ] Testing public API only (no `_private` name imported or called)
- [ ] Parametrized cases carry `pytest.param(..., id=...)` and named fields, never bare positional tuples
- [ ] No conditionals in test bodies (complexity = 1)
- [ ] Using in-memory implementations from the repository's test-support package
- [ ] No time.sleep (Event.wait, Queue.get with a timeout, an awaited future)
- [ ] Leaf types have 100% coverage
</unit_tests_checklist>

<integration_tests_checklist>
- [ ] Test seams between components
- [ ] Use in-memory or binary dependencies (avoid Docker)
- [ ] A pytest marker for optional execution (`@pytest.mark.integration`, registered in `pyproject.toml`)
- [ ] Cover happy path and error scenarios across boundaries
- [ ] Real or test-support implementations (no `mock.patch` of internal collaborators)
</integration_tests_checklist>

<system_tests_checklist>
- [ ] Located in tests/ folder at project root
- [ ] Black box testing via CLI (`subprocess.run`) or API (an HTTP client)
- [ ] Appropriate dependency level chosen (in-memory, binary, or test-containers)
- [ ] Tests critical end-to-end workflows
- [ ] Dependencies documented (what's needed to run tests)
- [ ] CI-compatible (either fast in-memory or containerized setup)
</system_tests_checklist>

<test_infrastructure_checklist>
- [ ] Reusable fakes live in an importable test-support package (`<pkg>/testing/` or `tests/support/`); `conftest.py` holds only the fixtures that hand them out
- [ ] Test infrastructure has its own tests
- [ ] DSL provides readable test setup
- [ ] Can be exposed as CLI for manual testing
</test_infrastructure_checklist>

See reference.md for the pytest harness catalogue.
