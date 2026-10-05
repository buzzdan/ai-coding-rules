1. **Does the diff validate a primitive inline instead of constructing a type?**
   Detect-grep: `^\s*(el)?if .*\b[a-zA-Z_.]+ (==|!=) ""|^\s*(el)?if .*\b[a-zA-Z_.]+ (<=?|>=?) [0-9]|^\s*(el)?if not [a-zA-Z_.]+:`
   Detection: the check often sits second in a compound condition (`if failed or
   days <= 0 or days > 365`), so the pattern reads the whole `if` line, not its first
   clause; `if not host:` is Python's emptiness check and counts.
   Violation: an emptiness/range/format check on a parameter or DTO field that names
   a domain concept (port, id, email, path, addr), outside a `__post_init__`, a
   `parse` classmethod or a pydantic validator.

2. **Is the same predicate enforced in more than one place?**
   Detect: judgment
   Detection: for each predicate found above, grep its normalized form across the
   package, e.g. `grep -rn '0 < .* <= 65535' --include='*.py' .` — count hits (a
   chained comparison and its `and`-joined twin, `0 < p and p <= 65535`, are one
   predicate).
   Violation: ≥2 hits — the rule has no single owner; a type is missing.

3. **Does named behavior run on a bare primitive?** Loops/matches over `list[str]`,
   Detect-grep: `== "[A-Z_]+"|case "[a-z_]+":|^\s*[a-z]\w* = "[a-z]+"$`
   string-literal status comparisons, format logic on a `str` field, a variable
   assigned one of a fixed set of literals under a flag.
   Detection: the first two alternatives find enum-shaped comparisons and `match`
   arms on raw strings; the third a literal assigned to a variable, then read whether
   the same variable takes a second literal under a
   condition (`scheme = "http"; if tls: scheme = "https"`) and whether that pair
   appears in more than one function; inspect the diff for loops whose body
   interprets a primitive. A `Literal["email", "slack"]` annotation names the set
   but carries no behavior; it scores like the bare string.
   Violation: behavior attached to a bare primitive where a named method on a type
   (a `StrEnum` with methods, a frozen dataclass) would carry it.

4. **Does any function return a sentinel to mean "not found / invalid"?**
   Detect-grep: `return (0|""|-1|None)\s*(#.*)?$`
   Detection: read each hit's signature: the hit is a sentinel when the return annotation
   promises a real value (`-> Device`, `-> int`) and the body returns `None`, `0` or
   `""` for the missing case. ty reports that `None` as `invalid-return-type` and mypy
   as `return-value`, so a `# ty: ignore[invalid-return-type]` or a
   `# type: ignore[return-value]` on the line is the same hit, silenced. A
   `-> X | None` signature is a declared absence and is not this question, as long
   as the `None` means "not there" and never "it failed" (R2 Q5 owns that line). A
   trailing comment (`return 0  # sentinel`) does not hide the hit.
   Violation: validity encoded in-band — requires `X | None` for a normal absence,
   or an exception for a failure; never `tuple[X, bool]`.

5. **Do the same parameters travel together across signatures?**
   Detect-grep: `^\s*def [A-Za-z_][A-Za-z0-9_]*\([^)]*,[^)]*,`
   Detection: for each changed function with ≥3 parameters, grep the package for the
   same parameter-name pair/trio in other signatures, e.g.
   `grep -rnE 'def .*host: str.*port: int' --include='*.py' .`; ruff `PLR0913`
   (too many arguments) marks the candidates.
   Violation: the same group of ≥2–3 parameters co-occurs in ≥2 signatures — a data
   clump; Introduce Parameter Object (score it: grouping-that-travels is +2 on the
   scorecard, plus its usage points).

6. **Inverse — is a NEW type in the diff mere ceremony?**
   Detect-grep: `^class [A-Z][A-Za-z0-9]*\((str|int|float)\):|^[A-Z][A-Za-z0-9]* = NewType\(`
   Detection: count its methods (`grep -cE '^    def ' <file>` between the `class`
   line and the next top-level statement) and check whether any method does more
   than unwrap or rename the primitive; score it with the scorecard above. A
   `NewType`, or a `class Name(str)` with no `__post_init__`, no validator and no
   method, scores 0 on the invariant line: it admits every literal.
   Violation: Score 0-1, or the only method is `return str(self)` —
   over-abstraction; the finding must cite the cheaper alternative
   (`../examples/overabstraction-cidr.md`).

7. **Does a nested container appear in a signature or a field?**
   Detect-grep: `(dict|list|tuple|set|frozenset|Mapping|Sequence|Iterable)\[[^]]*(dict|list|tuple|set|frozenset|Mapping|Sequence)\[`
   Detection: the pattern finds a container annotation whose parameter is itself a
   container — `dict[str, list[str]]`, `tuple[dict[object, object], str]`,
   `list[tuple[str, int]]` — in signatures, dataclass fields and module constants.
   Read the hit: `tuple[X, ...]` is an immutable sequence of `X`, one level, and
   `dict[Kind, Handler]` is a strategy map (R11); both are a single collection of a
   named type and are not this question.
   Violation: every remaining hit. The inner shape is a type with no name — Name the
   Container: a `NamedTuple` or frozen dataclass whose fields are the elements, or a
   class holding the mapping with the receivers' queries as methods (a nested
   container is +3 on the scorecard).

8. **Does a flat container of primitives cross a function boundary?**
   Detect-grep: `-> (dict|list|set|frozenset|tuple|Mapping|Sequence|Iterable)\[|^\s*def .*: (dict|Mapping)\[`
   Detection: the pattern finds a return annotation that is a container and a
   parameter annotated as a mapping. For each hit whose parameters are primitives
   (`dict[str, str]`, `tuple[str, str]`, `list[str]`), read every receiver and list
   what it does with the value: `[key]`, `.get(`, `in`, `len(`, a write, a `for k, v
   in …` loop that filters by key or value and extracts a part (grep the receivers
   for `for [a-z_]+, [a-z_]+ in`). The filtering loop is the strongest lead: it is a
   method already written. A hit already reported under Q7 belongs to Q7.
   Violation: two or more such operations, or two or more receivers, and no type owns
   them — a hidden abstraction; Name the Container (flat-crossing is +2 on the
   scorecard, and each named operation earns the "noun the story needs" points). A
   pass-through under a telling parameter name, or a container built and read inside
   one function, is not a finding.
