
> **In Python:** `# noqa`, `# ty: ignore` and `# type: ignore` are the same thing, and
> each carries its code (`# noqa: E501`, `# ty: ignore[invalid-return-type]`,
> `# type: ignore[return-value]`). A bare one names no rule: ruff `PGH003` flags a bare
> `# type: ignore`, nothing flags a bare `# ty: ignore`, and ty honors a bare
> `# type: ignore` too, so read for all three. `[tool.ruff.lint.per-file-ignores]` and a
> `[tool.ty]` or `[tool.mypy]` override are the reviewed place for a true false positive.

**Review:** Did the diff add a `# noqa`, `# ty: ignore` or `# type: ignore`, or edit `[tool.ruff]`, `[tool.ty]` or `[tool.mypy]`?
