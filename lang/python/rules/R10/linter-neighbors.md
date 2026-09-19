- **The linter owns the mechanical neighbors.** Swallowed exceptions (ruff `BLE001`,
  `S110`), bare `except:` (`E722`), a `raise` inside `except` without `from`
  (`B904`), unclosed files and connections (`SIM115`, and `with` blocks) — enforce
  these in `pyproject.toml`'s `[tool.ruff.lint]`; do not re-hunt them here. There is
  no race detector: an unguarded write is found by reading the code.
