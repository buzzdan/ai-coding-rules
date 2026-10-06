1. **Does the diff validate a primitive inline instead of constructing a type?**
   Detect-grep: `^\s*(\} else )?if \(.*\b[a-zA-Z_.]+ (===|!==) ''|^\s*(\} else )?if \(.*\b[a-zA-Z_.]+ (<=?|>=?) [0-9]|^\s*(\} else )?if \(!?[a-zA-Z_.]+(\.length|\.trim\(\))?\)|\{[a-zA-Z_.]+ (<=?|>=?) [0-9]`
   Detection: the check often sits second in a compound condition (`if (failed ||
   days <= 0 || days > 365)`), so the pattern reads the whole `if` line, not its
   first clause; `if (!host)` is TypeScript's emptiness check and counts, and so does
   the same predicate written as a JSX guard (`{port > 0 && port <= 65535 && <Link
   />}`), which the last alternative finds.
   Violation: an emptiness/range/format check on a parameter, a prop or a DTO field
   that names a domain concept (port, id, email, path, addr), outside a `parseX`
   factory, a type guard in `typeGuards.ts` or, where the repository has a schema
   library, a schema refinement.

2. **Is the same predicate enforced in more than one place?**
   Detect: judgment
   Detection: for each predicate found above, grep its normalized form across the
   source tree, e.g.
   `grep -rn '> 0 && .*<= 65535' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`
   — count hits (the predicate in a function body and its copy in a JSX condition
   are one predicate written twice). `sonarjs/no-identical-functions` marks the
   larger copies.
   Violation: ≥2 hits — the rule has no single owner; a type is missing.

3. **Does named behavior run on a bare primitive?** Loops/switches over `string[]`,
   Detect-grep: `(===|!==) '[a-z_-]+'|case '[a-z_-]+':|^\s*let [a-z]\w* = '[a-z]+'$`
   string-literal status comparisons, format logic on a `string` field, a variable
   assigned one of a fixed set of literals under a flag.
   Detection: the first two alternatives find enum-shaped comparisons
   (`status === 'online'`) and `switch` arms on raw strings; the third a literal
   assigned to a variable, then read whether the same variable takes a second
   literal under a condition (`let scheme = 'http'; if (tls) scheme = 'https'`) and
   whether that pair appears in more than one function; inspect the diff for loops
   whose body interprets a primitive. `sonarjs/no-duplicate-string` marks the
   literal repeated three times. A `kind: 'email' | 'slack'` union names the set
   but carries no behavior; it scores like the bare string until a
   `Record<Kind, …>` or a function keyed by it owns the behavior.
   Violation: behavior attached to a bare primitive where a named method on a type
   (an `as const` enum with functions over it, a factory-built `readonly` type)
   would carry it.

4. **Does any function return a sentinel to mean "not found / invalid"?**
   Detect-grep: `return (0|''|""|-1|null|undefined)\s*(//.*)?$|\bas [A-Z][A-Za-z]*\b|!\.|@ts-expect-error`
   Detection: read each hit's signature: the hit is a sentinel when the return type
   promises a real value (`: Device`, `: number`) and the body returns `-1`, `''`,
   `0` or `null` for the missing case. `tsc` rejects `return null` from a `: Device`
   function under `strict`, so that form arrives silenced — a `find(...)!`, an
   `as Device`, a `@ts-expect-error` on the line — and the silence is the same hit,
   which is why the last three alternatives find the cast, the non-null assertion
   and the directive; `-1`, `''` and `0` type-check against `number` and `string`,
   which is why the first exists. With `noUncheckedIndexedAccess` off, `items[0]`
   is typed `T` and a missing element is a silent `undefined` — the sentinel in its
   configuration form; the hunter reads `tsconfig` once to know which. A
   `: X | undefined` signature is a declared absence and is not this question, as
   long as the `undefined` means "not there" and never "it failed" (R2 Q5 owns that
   line). A trailing comment (`return 0 // sentinel`) does not hide the hit.
   Violation: validity encoded in-band — requires `X | undefined` for a normal
   absence, or a thrown error for a failure; never `[X, boolean]`.

5. **Do the same parameters travel together across signatures?**
   Detect-grep: `^\s*(export )?(async )?function [A-Za-z_][A-Za-z0-9_]*\([^)]*,[^)]*,|= (async )?\([^)]*,[^)]*,[^)]*\)(: [^=]+)? =>`
   Detection: the pattern finds a function or arrow with three or more parameters
   on one line; Prettier wraps a longer signature one parameter per line, and
   `max-params` (4) marks those. For each changed function with ≥3 parameters, grep
   the source tree for the same parameter-name pair/trio in other signatures, e.g.
   `grep -rnE 'function .*host: string.*port: number' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`.
   The React form is prop drilling: the same trio (`clusterId`, `tenantId`,
   `region`) declared in three components' props and forwarded by each —
   `grep -rn 'clusterId={' --include='*.tsx' --exclude-dir=node_modules .` per
   member, then read whether the same component passes all of them on.
   Violation: the same group of ≥2–3 parameters co-occurs in ≥2 signatures — a data
   clump; Introduce Parameter Object (score it: grouping-that-travels is +2 on the
   scorecard, plus its usage points).

6. **Inverse — is a NEW type in the diff mere ceremony?**
   Detect-grep: `^(export )?type [A-Z][A-Za-z0-9]* = (string|number|boolean)( & \{| *$)|^(export )?class [A-Z][A-Za-z0-9]* \{`
   Detection: the pattern finds a bare alias of a primitive, a brand and a class
   declaration. Count the type's methods (`grep -cE '^  [a-zA-Z]+\(.*\)(: [^{]+)? \{' <file>`
   between the `class` line and its closing brace, or the functions whose first
   parameter is the type) and check whether any does more than unwrap or rename the
   primitive; score it with the scorecard above. A `type X = number`, a brand with
   no validating factory, or an `interface` with one field and no behavior scores 0
   on the invariant line: it is erased and admits every literal (every cast, for the
   brand).
   Violation: Score 0-1, or the only method is `toString()`/`valueOf()` returning
   the primitive — over-abstraction; the finding must cite the cheaper alternative
   (`../examples/overabstraction-cidr.md`).

7. **Does a nested container appear in a signature or a field?**
   Detect-grep: `(Record|Map|Set|Array|ReadonlyArray|ReadonlyMap|ReadonlySet)<[^>]*(Record|Map|Set|Array|ReadonlyArray)<|\[\][]>]|\]\[\]|: \{ \[key: string\]:|\[[^]]*(Record|Map|Array)<`
   Detection: the pattern finds a container type whose parameter is itself a
   container — `Record<string, string[]>`, `Map<string, Set<number>>`,
   `string[][]`, `[Record<string, string>, string]`, an inline index signature
   whose value is an array — in signatures, `interface` and `type` fields, props
   and module constants. Read the hit: `readonly T[]` is one level, a
   `Record<Kind, Handler>` is a strategy map (R11), and `Promise<string[]>` or
   `useState<string[]>` wraps one collection; each is a single collection of a
   named type and is not this question.
   Violation: every remaining hit. The inner shape is a type with no name — Name the
   Container: a `readonly` object type whose fields are the elements, or a class
   holding the mapping with the receivers' queries as methods (a nested container
   is +3 on the scorecard).

8. **Does a flat container of primitives cross a function boundary?**
   Detect-grep: `\): (Promise<)?(Record<string, (string|number|boolean)>|(string|number)\[\]|Map<string, (string|number)>|\[string, string\])|\(([a-z]+: Record<string, string>|[a-z]+: string\[\])|^\s+readonly [a-zA-Z]+\??: (Record<string, (string|number)>|(string|number)\[\])`
   Detection: the pattern finds a return type that is a container of primitives, a
   parameter typed as one, and a prop declared as one. For each hit, read every
   receiver and list what it does with the value: `[key]`, `.get(`, `in`,
   `.length`, a write, a `for … of` over `Object.entries(…)` or a `.filter(` /
   `.find(` that filters by key or value and extracts a part (grep the receivers
   for `Object\.(entries|keys)\(` and `\.(filter|find|some)\(` on the name). The
   filtering loop is the strongest lead: it is a method already written. The React
   form is prop drilling of the shape: the same `Record` or array prop declared in
   two components' props and handed through, each reading a part of it. A hit
   already reported under Q7 belongs to Q7; a `string[]` of class names handed to
   `clsx` and `children` are not this question.
   Violation: two or more such operations, or two or more receivers, and no type owns
   them — a hidden abstraction; Name the Container (flat-crossing is +2 on the
   scorecard, and each named operation earns the "noun the story needs" points). A
   pass-through under a telling parameter name, or a container built and read inside
   one function, is not a finding.
