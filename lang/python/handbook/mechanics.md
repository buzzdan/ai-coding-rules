| Type check | `mypy`, where `pyproject.toml` has a `[tool.mypy]` table; never add a checker the repository does not use |
| Type suppression | `# type: ignore` — the same rule as `# noqa`, see P6 |
| Python | the examples assume 3.11+ (`match`, `X \| None`, `asyncio.TaskGroup`, `typing.assert_never`); on 3.10 import `assert_never` from `typing_extensions` and keep asyncio tasks under kept handles |
| Tests | pytest collects `test_*.py` and `*_test.py`; under `tests/` mirroring the package or beside the module, whichever the repository does; `pytest.param(id=...)` on every row |