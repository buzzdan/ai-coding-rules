**NEVER add `// eslint-disable-next-line`, `@ts-expect-error` or `@ts-ignore` to
avoid refactoring.** Handle the error, parse at the boundary, or reduce the
complexity. Before finishing, scan all uncommitted files:

```bash
changed_files=$({ git diff --name-only; git diff --cached --name-only; } | sort -u)
[ -n "$changed_files" ] && printf '%s\n' "$changed_files" | xargs grep -nE 'eslint-disable|@ts-(expect-error|ignore|nocheck)|prettier-ignore' 2>/dev/null
```

Any hit → remove the directive and fix properly. Genuine false positives belong in
`eslint.config.*` — a rule turned off for a named file glob — or in `tsconfig*.json`,
with user approval, never unilaterally.

An `eslint-disable` or `@ts-expect-error` that was already in a touched file is the
same hit when it names a rule routed this session and sits on a function, component
or type this session changed, or on a module-level declaration in a touched module
(`import/no-mutable-exports` → R8 in a globals request; `react-hooks/exhaustive-deps`
→ R10; an `@ts-expect-error` on `return undefined` → R1): it suppresses the rule it
names, so route it as a finding of that rule and delete it with the fix.
"Pre-existing" and "unrelated" are not verdicts for those — a request to make the
linter pass without suppressions is met when the touched functions and the touched
modules' top-level declarations carry none of the routed rules' directives, not when
the one directive the request named is gone and its neighbours keep their `// TODO`.
A directive elsewhere in a touched file, or one naming a rule this session never
routed — `sonarjs/cognitive-complexity` → R3 on the function whose one global read
was just replaced — is a BROADER CONTEXT line under the `Stop check` block: reported
with its rule, not fixed in this session, not silent.
