1. **Read project files** in order of preference:
   - `CLAUDE.md` (project-specific instructions)
   - `README.md` (project documentation)
   - `Makefile` (look for `test:` and `lint:` targets)
   - `Taskfile.yaml` (look for `test:` and `lint:` tasks)
   - `pyproject.toml` (`[tool.ruff]`, `[tool.ty]`, `[tool.mypy]`, `[tool.pytest.ini_options]`),
     `tox.ini`, `noxfile.py`, `.pre-commit-config.yaml` (which checkers the
     repository runs)

2. **Extract commands**:
   - **Test command**: `pytest`, `pytest --cov`, `make test`, `task test`, `tox -e py`
   - **Lint command (report-only)**: this command must NOT fix. Strip any `--fix`
     flag and run the checkers in report mode: `ruff check . && ruff format --check .`,
     plus `ty check` or `mypy` where the repository configures it (or the project's lint command
     with `--fix` removed).

3. **Fallback to defaults** if not found:
   - Test: `pytest`
   - Lint: `ruff check .` (no `--fix`); `ty check` only when a `[tool.ty]` table or
     `ty.toml` exists, `mypy` only when a `[tool.mypy]` table or `mypy.ini` exists
