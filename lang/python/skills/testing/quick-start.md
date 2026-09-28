1. **Find the lowest rung** that contains the behavior (see composition_ladder)
2. **Choose structure**: `@pytest.mark.parametrize` with `pytest.param(id=...)` (simple) or fixture-backed setup (complex infrastructure)
3. **Import as a consumer would** (`from app import user`) - test public API only, never a `_private` name
4. **Compose real layers** - in-memory/in-process implementations from the repository's test-support package
5. **Avoid pitfalls**: No `time.sleep`, no conditionals in test bodies, no `mock.patch` of internal collaborators

Ready after tests? Run linter: `ruff check --fix . && ruff format . && ty check` (or `mypy`, whichever the repository configures)
