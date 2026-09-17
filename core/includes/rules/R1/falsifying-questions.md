The detection below names what to search for; build each search over the language's
source files (`{{.SrcGlob}}`) with the repository's own grep or ripgrep, and read the
hits — a pattern finds candidates, the question decides.

1. **Does the diff validate a primitive inline instead of constructing a type?**
   Detection: in the changed files, find conditionals that compare a parameter or DTO
   field against an empty string, a number bound or a format (`== ""`, `<= 0`,
   `> 65535`, a regex match) — the check often sits second in a compound condition
   (`if failed or days <= 0 or days > 365`), so read the whole condition, not its
   first clause.
   Violation: an emptiness/range/format check on a parameter or DTO field that names
   a domain concept (port, id, email, path, addr), outside a `ParseX`/`NewX`
   constructor.

2. **Is the same predicate enforced in more than one place?**
   Detection: for each predicate found above, search its normalized form across the
   package or module (`> 0` and `<= 65535` together, the same regex, the same
   emptiness check on the same field name) — count hits.
   Violation: ≥2 hits — the rule has no single owner; a type is missing.

3. **Does named behavior run on a bare primitive?** Loops/switches over a list of
   strings, string-literal status comparisons, format logic on a string field, a
   variable assigned one of a fixed set of literals under a flag.
   Detection: search for enum-shaped comparisons (`== "READY"`, an upper-case string
   literal compared against a field); search for a lower-case literal assigned to a
   variable, then read whether the same variable takes a second literal under a
   condition (`scheme = "http"; if tls: scheme = "https"`) and whether that pair
   appears in more than one function; inspect the diff for loops whose body interprets
   a primitive.
   Violation: behavior attached to a bare primitive where a named method on a type
   would carry it.

4. **Does any function return a sentinel to mean "not found / invalid"?**
   Detection: in the changed files, find `return 0`, `return ""`, `return -1` and
   `return {{.Nil}}` (the language's missing value), then read each hit's signature:
   the hit is a sentinel when the signature promises a real value and has no separate
   absence or failure result (a missing value returned where a device is expected is
   one; the language's "no error" result is not). A trailing comment (`return 0 //
   sentinel`) does not hide the hit.
   Violation: validity encoded in-band — requires an explicit absence result (an
   optional, a found flag) or a failure.

5. **Do the same parameters travel together across signatures?**
   Detection: for each changed function with ≥3 parameters, search the package or
   module for the same parameter-name pair/trio in other signatures (`host` and `port`
   side by side in a second signature, say).
   Violation: the same group of ≥2–3 parameters co-occurs in ≥2 signatures — a data
   clump; Introduce Parameter Object (score it: grouping-that-travels is +2 on the
   scorecard, plus its usage points).

6. **Inverse — is a NEW type in the diff mere ceremony?**
   Detection: count its methods and check whether any method does more than unwrap or
   rename the primitive; score it with the scorecard above.
   Violation: Score 0-1, or the only method is `return <primitive>(x)` —
   over-abstraction; the finding must cite the cheaper alternative (better naming, or
   private fields with accessors).
