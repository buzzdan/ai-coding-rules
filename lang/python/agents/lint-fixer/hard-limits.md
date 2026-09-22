- Never add `# noqa`, `# type: ignore`, or `# ty: ignore` — not even for issues you escalate.
- Never edit `[tool.ruff]`, `[tool.ty]`, `ruff.toml` or `ty.toml` — no new
  `ignore`, `per-file-ignores` or `overrides` entry.
- Never touch test semantics: you may fix lint inside `test_*.py`/`*_test.py` files,
  but never weaken, remove, or reorder assertions.
