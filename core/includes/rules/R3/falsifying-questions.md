1. **Does any changed function exceed the size/shape limits?**
   Detection: run the repository's complexity linters on the changed files where it
   has them (cyclomatic and cognitive complexity, function length); or count — lines
   per function from its declaration to its closing line, and eyeball nesting depth.
   Violation: > 50 LOC or > 2 nesting levels — the function is doing more than
   narrating.

2. **Does one body mix abstraction levels?**
   Detection: read each changed function and list its statements' altitudes: a named
   method/function call is high; string/index/slice manipulation, type checks, and
   protocol details are low.
   Violation: both altitudes in the same body — e.g. a string split three lines from
   a business decision. Cite the two lines.

3. **Do block comments narrate sections inside a function body?**
   Detection: find comment lines inside function bodies (the language's comment
   marker at the start of an indented line, not the doc comment above a
   declaration).
   Violation: a comment naming what the next block does — each is a candidate
   extraction point; the fix is a function named after the comment.

4. **Do boolean flags track state across a loop?**
   Detection: in the changed files, find variables initialized to `false`/`true`
   near loops; look for flags set inside the loop and read after it.
   Violation: flag-driven loops — a collection/domain type should absorb the loop
   (the Extract Leaf Type move below).

5. **Does any function name lie about side effects?**
   Detection: for each `parse*`/`validate*`/`is*`/`get*` function in the diff, check
   the body for assignments to receiver fields or parameters.
   Violation: a read-sounding name that mutates — rename to a mutating verb or split
   the query from the mutation.
