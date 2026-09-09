
1. **Does any changed function exceed the size/shape limits?**
   Detection: run the complexity linters (`gocyclo`, `gocognit` via
   `golangci-lint run`) on the changed files; or count —
   `awk '/^func /,/^}/' <file>` per function for LOC, eyeball nesting depth.
   Violation: > 50 LOC or > 2 nesting levels — the function is doing more than
   narrating.

2. **Does one body mix abstraction levels?**
   Detection: read each changed function and list its statements' altitudes: a named
   method/function call is high; string/index/slice manipulation, type assertions,
   and protocol details are low.
   Violation: both altitudes in the same body — e.g. `strings.SplitN` three lines
   from a business decision. Cite the two lines.

3. **Do block comments narrate sections inside a function body?**
   Detection: `grep -n '^\s*//' <file>` within function bodies (not doc comments
   above declarations).
   Violation: a comment naming what the next block does — each is a candidate
   extraction point; the fix is a function named after the comment.

4. **Do boolean flags track state across a loop?**
   Detection: `grep -nE 'var \(|:= false|:= true' <changed files>` near `for` loops;
   look for flags set inside the loop and read after it.
   Violation: flag-driven loops — a collection/domain type should absorb the loop
   (see `../examples/storify-leaf-type.md`).

5. **Does any function name lie about side effects?**
   Detection: for each `parse*`/`validate*`/`is*`/`get*` function in the diff, check
   the body for assignments to receiver fields or parameters.
   Violation: a read-sounding name that mutates — rename to a mutating verb or split
   the query from the mutation.
