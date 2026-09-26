1. **Verify Python project**: `pyproject.toml` (or `setup.cfg`/`setup.py`) in root or
   parent directories; note the version `requires-python` pins — `match`, `StrEnum`,
   `asyncio.TaskGroup` and `queue.shutdown()` each have a floor.
2. **Discover commands** (README.md, CLAUDE.md, Makefile, Taskfile.yaml, the `[tool.*]`
   tables in `pyproject.toml`, `tox.ini`/`noxfile.py`, the CI workflow, in that
   order): test + lint commands, the mutation target when one exists (`mutate`,
   `mutmut`), and which checkers the repository runs — ruff alone,
   ruff plus a type checker (ty or mypy), or pyright/flake8/pylint. Fallbacks: `pytest`,
   `ruff check --fix . && ruff format .`; add `ty check` only when a `[tool.ty]` table or
   `ty.toml` exists, `mypy` only when a `[tool.mypy]` table or `mypy.ini` exists. Never
   bring a checker the repository does not configure.
