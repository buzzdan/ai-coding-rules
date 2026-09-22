**NEVER add `# noqa`, `# type: ignore`, or `# ty: ignore` to avoid refactoring.** Handle the error,
validate at the boundary, or reduce the complexity. Before finishing, scan all
uncommitted files:

```bash
changed_files=$({ git diff --name-only; git diff --cached --name-only; } | sort -u)
[ -n "$changed_files" ] && printf '%s\n' "$changed_files" | xargs grep -nE '# *(noqa|(ty|type): *ignore)' 2>/dev/null
```

Any hit → remove the directive and fix properly. Genuine false positives belong in
`pyproject.toml` — `[tool.ruff.lint] ignore`/`per-file-ignores`, a
`[[tool.ty.overrides]]` block — with user approval, never unilaterally.

A `# noqa`, `# type: ignore`, or `# ty: ignore` that was already in a touched file is the same hit
when it names a rule routed this session and sits on a function or class this
session changed, or on a module-level statement in a touched module (`PLW0603` →
R8 in a globals request; `# ty: ignore[invalid-return-type]` on a `return None` → R1):
it suppresses the rule it names, so route it as a finding of that rule and delete it
with the fix. "Pre-existing" and "unrelated" are not verdicts for those — a request
to make the linter pass without suppressions is met when the touched functions and
the touched modules' top-level statements carry none of the routed rules'
directives, not when the one directive the request named is gone and its neighbours
keep their `# TODO`. A directive elsewhere in a touched file, or one naming a rule
this session never routed — `C901,PLR0912` → R3 on the function whose one global
read was just replaced — is a BROADER CONTEXT line under the `Stop check` block:
reported with its rule, not fixed in this session, not silent.
