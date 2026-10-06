The detection below names what to search for; build each search over the language's
source files (`{{.SrcGlob}}`) with the repository's own grep or ripgrep, and read the
hits — a pattern finds candidates, the question decides.

1. **Does the diff validate a primitive inline instead of constructing a type?**
   Detect-grep: `\b(if|elif|else if) .*\b[a-zA-Z_.]+ (==|!=) ""|\b(if|elif|else if) .*\b[a-zA-Z_.]+ (<=?|>=?) [0-9]`
   Detection: in the changed files, find conditionals that compare a parameter or DTO
   field against an empty string, a number bound or a format (`== ""`, `<= 0`,
   `> 65535`, a regex match) — the check often sits second in a compound condition
   (`if failed or days <= 0 or days > 365`), so read the whole condition, not its
   first clause.
   Violation: an emptiness/range/format check on a parameter or DTO field that names
   a domain concept (port, id, email, path, addr), outside a `ParseX`/`NewX`
   constructor.

2. **Is the same predicate enforced in more than one place?**
   Detect: judgment
   Detection: for each predicate found above, search its normalized form across the
   package or module (`> 0` and `<= 65535` together, the same regex, the same
   emptiness check on the same field name) — count hits.
   Violation: ≥2 hits — the rule has no single owner; a type is missing.

3. **Does named behavior run on a bare primitive?** Loops/switches over a list of
   Detect-grep: `== "[A-Z_]+"`
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
   Detect-grep: `\breturn (0|""|-1)\s*([/#].*)?$`
   Detection: in the changed files, find `return 0`, `return ""`, `return -1` and
   `return {{.Nil}}` (the language's missing value), then read each hit's signature:
   the hit is a sentinel when the signature promises a real value and has no separate
   absence or failure result (a missing value returned where a device is expected is
   one; the language's "no error" result is not). A trailing comment (`return 0 //
   sentinel`) does not hide the hit.
   Violation: validity encoded in-band — requires an explicit absence result (an
   optional, a found flag) or a failure.

5. **Do the same parameters travel together across signatures?**
   Detect: judgment
   Detection: for each changed function with ≥3 parameters, search the package or
   module for the same parameter-name pair/trio in other signatures (`host` and `port`
   side by side in a second signature, say).
   Violation: the same group of ≥2–3 parameters co-occurs in ≥2 signatures — a data
   clump; Introduce Parameter Object (score it: grouping-that-travels is +2 on the
   scorecard, plus its usage points).

6. **Inverse — is a NEW type in the diff mere ceremony?**
   Detect: judgment
   Detection: count its methods and check whether any method does more than unwrap or
   rename the primitive; score it with the scorecard above.
   Violation: Score 0-1, or the only method is `return <primitive>(x)` —
   over-abstraction; the finding must cite the cheaper alternative (better naming, or
   private fields with accessors).

7. **Does a nested container appear in a signature or a field?**
   Detect: judgment
   Detection: in the changed files, read every function signature and type field for
   a container whose parameter is itself a container — a map of maps, a list of
   lists, a list of pairs, a tuple that holds a mapping or a list — in the language's
   own spelling.
   Violation: every hit. The inner shape is a type with no name — Name the Container
   (a nested container is +3 on the scorecard). A single collection of a domain type
   (a list of ports, a strategy map of handlers keyed by an enum) is not nesting: its
   element has a name.

8. **Does a flat container of primitives cross a function boundary?**
   Detect: judgment
   Detection: in the changed files, find every function that returns or accepts a
   map, list, set or tuple of primitives. For each, read every receiver and list what
   it does with the value: a lookup by key, a membership test, a length check, a
   write, a loop that filters by key or value and extracts a part. The filtering loop
   is the strongest lead: it is a method already written, missing its name and its
   owner. A hit already reported under Q7 belongs to Q7.
   Violation: two or more such operations, or two or more receivers, and no type owns
   them — a hidden abstraction; Name the Container (flat-crossing is +2 on the
   scorecard, and each named operation earns the "noun the story needs" points). A
   pass-through under a telling parameter name, or a container built and read inside
   one function, is not a finding.
