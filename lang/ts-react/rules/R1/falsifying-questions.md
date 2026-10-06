1. **Does the diff validate a primitive inline instead of constructing a type?**
   Detection: `grep -nE "^\s*(} else )?if \(.*\b[a-zA-Z_.]+ (===|!==) ''|^\s*(} else )?if \(.*\b[a-zA-Z_.]+ (<=?|>=?) [0-9]|^\s*(} else )?if \(!?[a-zA-Z_.]+(\.length|\.trim\(\))?\)" $(git diff --name-only -- '*.ts' '*.tsx')`
   — the check often sits second in a compound condition (`if (failed || days <= 0
   || days > 365)`), so the pattern reads the whole `if` line, not its first clause;
   `if (!host)` is TypeScript's emptiness check and counts, and so does the same
   predicate written as a JSX guard (`{port > 0 && port <= 65535 && <Link />}`).
   Violation: an emptiness/range/format check on a parameter, a prop or a DTO field
   that names a domain concept (port, id, email, path, addr), outside a `parseX`
   factory, a type guard in `typeGuards.ts` or, where the repository has a schema
   library, a schema refinement.

2. **Is the same predicate enforced in more than one place?**
   Detection: for each predicate found above, grep its normalized form across the
   source tree, e.g.
   `grep -rn '> 0 && .*<= 65535' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`
   — count hits (the predicate in a function body and its copy in a JSX condition
   are one predicate written twice). `sonarjs/no-identical-functions` marks the
   larger copies.
   Violation: ≥2 hits — the rule has no single owner; a type is missing.

3. **Does named behavior run on a bare primitive?** Loops/switches over `string[]`,
   string-literal status comparisons, format logic on a `string` field, a variable
   assigned one of a fixed set of literals under a flag.
   Detection: `grep -rnE "(===|!==) '[a-z_-]+'|case '[a-z_-]+':" --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`
   for enum-shaped comparisons (`status === 'online'`) and `switch` arms on raw
   strings; `grep -rnE "^\s*let [a-z]\w* = '[a-z]+'$" --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`
   for a literal assigned to a variable, then read whether the same variable takes a
   second literal under a condition (`let scheme = 'http'; if (tls) scheme =
   'https'`) and whether that pair appears in more than one function; inspect the
   diff for loops whose body interprets a primitive. `sonarjs/no-duplicate-string`
   marks the literal repeated three times. A `kind: 'email' | 'slack'` union names
   the set but carries no behavior; it scores like the bare string until a
   `Record<Kind, …>` or a function keyed by it owns the behavior.
   Violation: behavior attached to a bare primitive where a named method on a type
   (an `as const` enum with functions over it, a factory-built `readonly` type)
   would carry it.

4. **Does any function return a sentinel to mean "not found / invalid"?**
   Detection: `grep -nE "return (0|''|-1|null|undefined)\s*(//.*)?$" $(git diff --name-only -- '*.ts' '*.tsx')`,
   then read each hit's signature: the hit is a sentinel when the return type
   promises a real value (`: Device`, `: number`) and the body returns `-1`, `''`,
   `0` or `null` for the missing case. `tsc` rejects `return null` from a `: Device`
   function under `strict`, so that form arrives silenced — a `find(...)!`, an
   `as Device`, a `@ts-expect-error` on the line — and the silence is the same hit;
   `-1`, `''` and `0` type-check against `number` and `string`, which is why the
   grep exists. With `noUncheckedIndexedAccess` off, `items[0]` is typed `T` and a
   missing element is a silent `undefined` — the sentinel in its configuration form;
   the hunter reads `tsconfig` once to know which. A `: X | undefined` signature is a declared absence and is not this
   question, as long as the `undefined` means "not there" and never "it failed"
   (R2 Q5 owns that line). A trailing comment (`return 0 // sentinel`) does not hide
   the hit.
   Violation: validity encoded in-band — requires `X | undefined` for a normal
   absence, or a thrown error for a failure; never `[X, boolean]`.

5. **Do the same parameters travel together across signatures?**
   Detection: for each changed function with ≥3 parameters, grep the source tree for
   the same parameter-name pair/trio in other signatures, e.g.
   `grep -rnE 'function .*host: string.*port: number' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`;
   `max-params` (4) marks the candidates. The React form is prop drilling: the same
   trio (`clusterId`, `tenantId`, `region`) declared in three components' props and
   forwarded by each — `grep -rn 'clusterId={' --include='*.tsx' --exclude-dir=node_modules .`
   per member, then read whether the same component passes all of them on.
   Violation: the same group of ≥2–3 parameters co-occurs in ≥2 signatures — a data
   clump; Introduce Parameter Object (score it: grouping-that-travels is +2 on the
   scorecard, plus its usage points).

6. **Inverse — is a NEW type in the diff mere ceremony?**
   Detection: count its methods (`grep -cE '^  [a-zA-Z]+\(.*\)(: [^{]+)? \{' <file>`
   between the `class` line and its closing brace, or the functions whose first
   parameter is the type) and check whether any does more than unwrap or rename the
   primitive; score it with the scorecard above. A `type X = number`, a brand with
   no validating factory, or an `interface` with one field and no behavior scores 0
   on the invariant line: it is erased and admits every literal (every cast, for the
   brand).
   Violation: Score 0-1, or the only method is `toString()`/`valueOf()` returning
   the primitive — over-abstraction; the finding must cite the cheaper alternative
   (`../examples/overabstraction-cidr.md`).
