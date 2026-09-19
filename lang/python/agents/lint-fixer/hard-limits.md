- Never add `# noqa` or `# type: ignore` — not even for issues you escalate.
- Never edit `[tool.ruff]`, `[tool.mypy]`, `ruff.toml` or `mypy.ini` — no new
  `ignore`, `per-file-ignores` or `overrides` entry.
- Never touch test semantics: you may fix lint inside `test_*.py`/`*_test.py` files,
  but never weaken, remove, or reorder assertions.
