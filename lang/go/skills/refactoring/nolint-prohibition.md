**NEVER add `//nolint` to avoid refactoring.** Handle the error, validate at the
boundary, or reduce the complexity. Before finishing, scan all uncommitted files:

```bash
changed_files=$({ git diff --name-only; git diff --cached --name-only; } | sort -u)
[ -n "$changed_files" ] && printf '%s\n' "$changed_files" | xargs grep "//nolint" 2>/dev/null
```

Any hit → remove the directive and fix properly. Genuine false positives belong in
`.golangci.yaml` exclusions — with user approval, never unilaterally.

A `//nolint` that was already in a touched file is the same hit when it sits on a
function or type this session changed, or on a package-level declaration in a touched
package (`gochecknoglobals` → R8, `gochecknoinits` → R8): it suppresses the rule it
names, so route it as a finding of that rule and delete it with the fix. "Pre-existing"
and "unrelated" are not verdicts for those — a request to make the linter pass without
suppressions is met when the touched functions and the touched packages' declarations
carry none, not when the one directive the request named is gone and its neighbours
keep their `// TODO`. A directive elsewhere in a touched file — `gocyclo` → R3 on a
function this session never opened — is a BROADER CONTEXT line under the `Stop check`
block: reported with its rule, not fixed in this session, not silent.
