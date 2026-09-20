| Type check | `mypy`, where `pyproject.toml` has a `[tool.mypy]` table; the plugin never adds a checker the repository does not use |
| Tests | pytest collects `test_*.py` and `*_test.py`; `pytest.param(id=...)` on every row; fixtures for infrastructure only |
