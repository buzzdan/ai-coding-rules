
> **In Python:** `# noqa` and `# ty: ignore` are the same thing, and each carries
> its code (`# noqa: E501`, `# ty: ignore[invalid-return-type]`; a bare one loses its rule name
> ). `[tool.ruff.lint.per-file-ignores]` and a `[tool.ty]` override are
> the reviewed place for a true false positive.

**Review:** Did the diff add a `# noqa` or `# ty: ignore`, or edit `[tool.ruff]` or `[tool.ty]`?
