1. **Does any changed function exceed the size/shape limits?**
   Detection: run the complexity rules (`sonarjs/cognitive-complexity`,
   `sonarjs/cyclomatic-complexity`, `sonarjs/max-lines-per-function`,
   `sonarjs/nested-control-flow`; `react/no-unstable-nested-components` for a
   component declared inside another) with `npx eslint` on the changed files; or
   count — `awk '/^(export )?(async )?function /,/^}/' <file>` per function for LOC,
   eyeball nesting depth. Nested JSX ternaries (`a ? <X /> : b ? <Y /> : <Z />`)
   are nesting levels, and a component past `max-lines-per-function` is the fat
   function.
   Violation: > 50 LOC or > 2 nesting levels — the function is doing more than
   narrating.

2. **Does one body mix abstraction levels?**
   Detection: read each changed function and list its statements' altitudes: a named
   function/hook call is high; string slicing, `.split()`, index arithmetic,
   `typeof`/`in` checks, and protocol details (`response.json()`, header parsing,
   `URLSearchParams` decoding) are low.
   Violation: both altitudes in the same body — e.g. `line.split(',', 2)` three
   lines from a business decision, or a date-format call beside a JSX branch. Cite
   the two lines. An IIFE inside a function body or a render tree
   (`{(() => { switch (status) { … } })()}`) is a low-altitude block that was never
   named — Extract Function (a component, in a render tree), or a lookup object when
   the body is a `switch` (`R11-conditional-dispatch.md`).

3. **Do block comments narrate sections inside a function body?**
   Detection: `grep -nE '^\s+// |\{/\* ' <file>` within function and component
   bodies (not the JSDoc above a declaration, not an `eslint-disable` or
   `@ts-expect-error` directive); `// --- filters ---` and `{/* header */}` in a
   render tree count.
   Violation: a comment naming what the next block does — each is a candidate
   extraction point; the fix is a function, or in a render tree a component, named
   after the comment (placed per `R4-helper-placement.md`).

4. **Do boolean flags track state across a loop?**
   Detection: `grep -nE '^\s+let [a-zA-Z_]+ = (false|true)$' <changed files>` near
   `for`, `while` and `.forEach` loops; look for flags set inside the loop and read
   after it, and for a `return` inside a `forEach` callback meant as a `break` — it
   is not one, and the flag it sets is the loop state in disguise.
   Violation: flag-driven loops — a collection/domain type (or a `find`/`some`/
   `reduce` on it) should absorb the loop (see
   `../examples/storify-leaf-type.md`).

5. **Does any function name lie about side effects?**
   Detection: for each `parse*`/`validate*`/`is*`/`get*` function in the diff,
   check the body for assignments to a parameter's properties, a `.push()`/
   `.splice()`/`.sort()` on an argument, a state-setter call, or a `ref.current =` write.
   Violation: a read-sounding name that mutates — rename to a mutating verb or split
   the query from the mutation; a `getX` that calls a state setter is the same
   finding with a worse disguise.
