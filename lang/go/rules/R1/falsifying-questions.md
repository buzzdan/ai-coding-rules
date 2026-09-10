1. **Does the diff validate a primitive inline instead of constructing a type?**
   Detection: `grep -nE 'if [a-zA-Z_.]+ (==|!=) ""|if [a-zA-Z_.]+ (<=?|>=?) [0-9]' $(git diff --name-only -- '*.go')`
   Violation: an emptiness/range/format check on a parameter or DTO field that names
   a domain concept (port, id, email, path, addr), outside a `ParseX`/`NewX`
   constructor.

2. **Is the same predicate enforced in more than one place?**
   Detection: for each predicate found above, grep its normalized form across the
   package, e.g. `grep -rn '> 0 && .*<= 65535' --include='*.go' .` — count hits.
   Violation: ≥2 hits — the rule has no single owner; a type is missing.

3. **Does named behavior run on a bare primitive?** Loops/switches over `[]string`,
   string-literal status comparisons, format logic on a `string` field.
   Detection: `grep -rnE '== "[A-Z_]+"' --include='*.go' .` for enum-shaped
   comparisons; inspect diff for loops whose body interprets a primitive.
   Violation: behavior attached to a bare primitive where a named method on a type
   would carry it.

4. **Does any function return a sentinel to mean "not found / invalid"?**
   Detection: grep the diff for `return 0`, `return ""`, `return -1` in functions
   whose signature has no `bool` or `error` result.
   Violation: validity encoded in-band — requires comma-ok or `(X, error)`.

5. **Do the same parameters travel together across signatures?**
   Detection: for each changed function with ≥3 parameters, grep the package for the
   same parameter-name pair/trio in other signatures, e.g.
   `grep -rnE 'func .*host string.*port int' --include='*.go' .`
   Violation: the same group of ≥2–3 parameters co-occurs in ≥2 signatures — a data
   clump; Introduce Parameter Object (score it: grouping-that-travels is +2 on the
   scorecard, plus its usage points).

6. **Inverse — is a NEW type in the diff mere ceremony?**
   Detection: count its methods (`grep -c 'func ([a-z0-9]* *\*\?<Type>)' <file>`) and
   check whether any method does more than unwrap or rename the primitive; score it
   with the scorecard above.
   Violation: Score 0-1, or the only method is `return <primitive>(x)` —
   over-abstraction; the finding must cite the cheaper alternative
   (`../examples/overabstraction-cidr.md`).
