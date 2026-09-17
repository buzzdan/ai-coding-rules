1. **Does the diff validate a primitive inline instead of constructing a type?**
   Detection: `grep -nE '^\s*(} else )?if .*\b[a-zA-Z_.]+ (==|!=) ""|^\s*(} else )?if .*\b[a-zA-Z_.]+ (<=?|>=?) [0-9]' $(git diff --name-only -- '*.go')`
   — the check often sits second in a compound condition (`if err != nil || days <= 0
   || days > 365`), so the pattern reads the whole `if` line, not its first clause.
   Violation: an emptiness/range/format check on a parameter or DTO field that names
   a domain concept (port, id, email, path, addr), outside a `ParseX`/`NewX`
   constructor.

2. **Is the same predicate enforced in more than one place?**
   Detection: for each predicate found above, grep its normalized form across the
   package, e.g. `grep -rn '> 0 && .*<= 65535' --include='*.go' .` — count hits.
   Violation: ≥2 hits — the rule has no single owner; a type is missing.

3. **Does named behavior run on a bare primitive?** Loops/switches over `[]string`,
   string-literal status comparisons, format logic on a `string` field, a variable
   assigned one of a fixed set of literals under a flag.
   Detection: `grep -rnE '== "[A-Z_]+"' --include='*.go' .` for enum-shaped
   comparisons; `grep -rnE '^\s*[a-z]\w* :?= "[a-z]+"$' --include='*.go' .` for a
   literal assigned to a variable, then read whether the same variable takes a second
   literal under a condition (`scheme := "http"; if tls { scheme = "https" }`) and
   whether that pair appears in more than one function; inspect diff for loops whose
   body interprets a primitive.
   Violation: behavior attached to a bare primitive where a named method on a type
   would carry it.

4. **Does any function return a sentinel to mean "not found / invalid"?**
   Detection: `grep -nE 'return (0|""|-1|nil)\s*(//.*)?$' $(git diff --name-only -- '*.go')`,
   then read each hit's function signature: the hit is a sentinel when the signature
   has no `bool` or `error` result (`return nil` from a `*Device` result is one; from
   an `error` result it is not). A trailing comment (`return 0 // sentinel`) does not
   hide the hit.
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
