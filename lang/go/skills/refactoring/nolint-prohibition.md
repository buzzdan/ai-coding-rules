**NEVER add `//nolint` to avoid refactoring.** Handle the error, validate at the
boundary, or reduce the complexity. Before finishing, scan all uncommitted files:

```bash
changed_files=$({ git diff --name-only; git diff --cached --name-only; } | sort -u)
[ -n "$changed_files" ] && printf '%s\n' "$changed_files" | xargs grep "//nolint" 2>/dev/null
```

Any hit → remove the directive and fix properly. Genuine false positives belong in
`.golangci.yaml` exclusions — with user approval, never unilaterally.
