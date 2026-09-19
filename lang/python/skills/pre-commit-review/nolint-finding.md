Also in-context: a new `# noqa` or `# type: ignore` in the diff, or a new
`ignore`/`per-file-ignores` entry under `[tool.ruff.lint]` or a new
`[[tool.mypy.overrides]]` block, is itself a finding — the change must justify, with
evidence, that the rule genuinely does not apply. Both directives are suppressions:
a `# type: ignore[return-value]` on a `return None` silences R1 Q4 as surely as a
`# noqa: PLW0603` silences R8.
