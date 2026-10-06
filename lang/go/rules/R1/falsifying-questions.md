1. **Does the diff validate a primitive inline instead of constructing a type?**
   Detect-grep: `^\s*(} else )?if .*\b[a-zA-Z_.]+ (==|!=) ""|^\s*(} else )?if .*\b[a-zA-Z_.]+ (<=?|>=?) [0-9]`
   Detection: the check often sits second in a compound condition (`if err != nil ||
   days <= 0 || days > 365`), so the pattern reads the whole `if` line, not its first
   clause.
   Violation: an emptiness/range/format check on a parameter or DTO field that names
   a domain concept (port, id, email, path, addr), outside a `ParseX`/`NewX`
   constructor.

2. **Is the same predicate enforced in more than one place?**
   Detect: judgment
   Detection: for each predicate found above, grep its normalized form across the
   package, e.g. `grep -rn '> 0 && .*<= 65535' --include='*.go' .` — count hits.
   Violation: ≥2 hits — the rule has no single owner; a type is missing.

3. **Does named behavior run on a bare primitive?** Loops/switches over `[]string`,
   string-literal status comparisons, format logic on a `string` field, a variable
   assigned one of a fixed set of literals under a flag.
   Detect-grep: `== "[A-Z_]+"|^\s*[a-z]\w* :?= "[a-z]+"$`
   Detection: the first alternative finds enum-shaped comparisons; the second a
   literal assigned to a variable, then read whether the same variable takes a second
   literal under a condition (`scheme := "http"; if tls { scheme = "https" }`) and
   whether that pair appears in more than one function; inspect diff for loops whose
   body interprets a primitive.
   Violation: behavior attached to a bare primitive where a named method on a type
   would carry it.

4. **Does any function return a sentinel to mean "not found / invalid"?**
   Detect-grep: `return (0|""|-1|nil)\s*(//.*)?$`
   Detection: read each hit's function signature: the hit is a sentinel when the signature
   has no `bool` or `error` result (`return nil` from a `*Device` result is one; from
   an `error` result it is not). A trailing comment (`return 0 // sentinel`) does not
   hide the hit.
   Violation: validity encoded in-band — requires comma-ok or `(X, error)`.

5. **Do the same parameters travel together across signatures?**
   Detect-grep: `^func (\([^)]*\) )?[A-Za-z_][A-Za-z0-9_]*\([^)]*,[^)]*,`
   Detection: for each changed function with ≥3 parameters, grep the package for the
   same parameter-name pair/trio in other signatures, e.g.
   `grep -rnE 'func .*host string.*port int' --include='*.go' .`
   Violation: the same group of ≥2–3 parameters co-occurs in ≥2 signatures — a data
   clump; Introduce Parameter Object (score it: grouping-that-travels is +2 on the
   scorecard, plus its usage points).

6. **Inverse — is a NEW type in the diff mere ceremony?**
   Detect-grep: `^type [A-Z][A-Za-z0-9]* (string|u?int(8|16|32|64)?|float(32|64)|bool|\[\]string)$`
   Detection: count its methods (`grep -c 'func ([a-z0-9]* *\*\?<Type>)' <file>`) and
   check whether any method does more than unwrap or rename the primitive; score it
   with the scorecard above.
   Violation: Score 0-1, or the only method is `return <primitive>(x)` —
   over-abstraction; the finding must cite the cheaper alternative
   (`../examples/overabstraction-cidr.md`).

7. **Does a nested container appear in a signature or a field?**
   Detect-grep: `(map\[[^]]+\]|\[\])(map\[|\[\])`
   Detection: the pattern finds a map or slice whose element is itself a map or
   slice — `map[string]map[string]int`, `map[string][]string`, `[][]string`,
   `[]map[string]any` — in signatures, struct fields and package-level declarations.
   Read the hit: `[][]byte` is a list of blobs, and a `map[string]struct{}` is a set,
   one level; neither is this question.
   Violation: every remaining hit. The inner shape is a type with no name — Name the
   Container: a named type that holds the container, with the receivers' lookups and
   loops as its methods (a nested container is +3 on the scorecard).

8. **Does a flat container of primitives cross a function boundary?**
   Detect-grep: `^func .*(map\[(string|int[0-9]*)\](string|int[0-9]*|bool|any|interface\{\})|\[\](string|int[0-9]*|bool|float64))`
   Detection: the pattern finds a signature that accepts or returns a map or slice of
   primitives. For each hit, read every receiver and list what it does with the
   value: an index, a comma-ok lookup, `len(`, a write, a `for k, v := range` loop
   that filters by key or value and extracts a part (grep the receivers for
   `range <name>`). The filtering loop is the strongest lead: it is a method already
   written. A hit already reported under Q7 belongs to Q7; `args []string` at an
   entry point and a `[]byte` are not this question. Go has no tuple: a function
   with several loose results is Q5's data clump (Introduce Parameter Object),
   never this question.
   Violation: two or more such operations, or two or more receivers, and no type owns
   them — a hidden abstraction; Name the Container (flat-crossing is +2 on the
   scorecard, and each named operation earns the "noun the story needs" points). A
   pass-through under a telling parameter name, or a container built and read inside
   one function, is not a finding.
