
> **In Python:** `# noqa` and `# type: ignore` are the same thing, and each carries
> its code (`# noqa: E501`, `# type: ignore[return-value]`; a bare one is ruff
> `PGH003`). `[tool.ruff.lint.per-file-ignores]` and a `[tool.mypy]` override are
> the reviewed place for a true false positive.

**Review:** Did the diff add a `# noqa` or `# type: ignore`, or edit `[tool.ruff]` or `[tool.mypy]`?
