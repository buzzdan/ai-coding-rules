1. **Does any changed function exceed the size/shape limits?**
   Detect: judgment
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
   Detect-grep: `^\s*return .*\(.*\), |^\s*return .*\.slice\(|^\s*return \[.*\(.*\)`
   Detection: the pattern is one lead, not the whole question: a `return` whose
   elements are expressions rather than names — a call beside a call, a slice, an
   array literal of calls — such as `return [parseHeader(lines.slice(0, i)),
   lines.slice(i + 1).join('\n')]`. Each such element has a meaning and no name: a
   local, or a method on the type the result belongs to
   (`R1-primitive-obsession.md`, Name the Container). Then read each changed
   function and list its statements' altitudes: a named function/hook call is high;
   string slicing, `.split()`, index arithmetic, `typeof`/`in` checks, and protocol
   details (`response.json()`, header parsing, `URLSearchParams` decoding) are low.
   Violation: both altitudes in the same body — e.g. `line.split(',', 2)` three
   lines from a business decision, or a date-format call beside a JSX branch. Cite
   the two lines. An IIFE inside a function body or a render tree
   (`{(() => { switch (status) { … } })()}`) is a low-altitude block that was never
   named — Extract Function (a component, in a render tree), or a lookup object when
   the body is a `switch` (`R11-conditional-dispatch.md`).

3. **Do block comments narrate sections inside a function body?**
   Detect-grep: `^\s*// |\{/\* `
   Detection: hits within function and component bodies (not the JSDoc above a
   declaration, not a comment above a top-level declaration, not an
   `eslint-disable`, `@ts-expect-error` or `prettier-ignore` directive — the hunter
   skips those); `// --- filters ---` and `{/* header */}` in a render tree count.
   Violation: a comment naming what the next block does — each is a candidate
   extraction point; the fix is a function, or in a render tree a component, named
   after the comment (placed per `R4-helper-placement.md`). Quote each comment's
   text with its line: the comment is the evidence and the function's name.

4. **Do boolean flags track state across a loop?**
   Detect-grep: `^\s+let [a-zA-Z_]+(: boolean)? = (false|true)(,|$)`
   Detection: hits near `for`, `while` and `.forEach` loops; look for flags set
   inside the loop and read after it, and for a `return` inside a `forEach` callback
   meant as a `break` — it is not one, and the flag it sets is the loop state in
   disguise.
   Violation: flag-driven loops — a collection/domain type (or a `find`/`some`/
   `reduce` on it) should absorb the loop (see
   `../examples/storify-leaf-type.md`).

5. **Does any function name lie about side effects?**
   Detect-grep: `^\s*(export )?(async )?function (parse|validate|is|get)[A-Z][a-zA-Z]*\(|^\s*(export )?const (parse|validate|is|get)[A-Z][a-zA-Z]* = |^\s+get [a-zA-Z_]+\(\)`
   Detection: for each `parse*`/`validate*`/`is*`/`get*` function and each `get`
   accessor the pattern lists in the diff, check the body for assignments to a
   parameter's properties, a `.push()`/`.splice()`/`.sort()` on an argument, a
   state-setter call, or a `ref.current =` write.
   Violation: a read-sounding name that mutates — rename to a mutating verb or split
   the query from the mutation; a `getX` that calls a state setter is the same
   finding with a worse disguise.
