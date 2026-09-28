Also in-context: a new `# noqa`, `# type: ignore`, or `# ty: ignore` in the diff, or a new
`ignore`/`per-file-ignores` entry under `[tool.ruff.lint]` or a new
`[[tool.ty.overrides]]` or `[[tool.mypy.overrides]]` block, is itself a finding — the
change must justify, with evidence, that the rule genuinely does not apply. All three
directives are suppressions: a `# ty: ignore[invalid-return-type]` or a
`# type: ignore[return-value]` on a `return None` silences R1 Q4 as surely as a
`# noqa: PLW0603` silences R8.
