1. **Does any changed function exceed the size/shape limits?**
   Detect: judgment
   Detection: run the complexity rules (ruff `C901`; `PLR0912` branches, `PLR0915`
   statements, `PLR0911` returns; `PLR1702` nesting where the repository enables
   preview rules) on the changed files; or count —
   `awk '/^(    )?def /,/^$/' <file>` per function for LOC, eyeball nesting depth.
   Violation: > 50 LOC or > 2 nesting levels — the function is doing more than
   narrating.

2. **Does one body mix abstraction levels?**
   Detect-grep: `^\s*return .*\(.*\), |^\s*return .*\[[^]]*:[^]]*\]`
   Detection: the pattern is one lead, not the whole question: a `return` whose
   elements are expressions rather than names — a call beside a call, a slice —
   such as `return _load("".join(lines[1:i])), "".join(lines[i + 1 :])`. Each such
   element has a meaning and no name: a local, or a method on the type the result
   belongs to (`R1-primitive-obsession.md`, Name the Container). Then read each
   changed function and list its statements' altitudes: a named
   method/function call is high; string slicing, `.split()`/`.partition()`, index
   arithmetic, `isinstance` checks, and protocol details (`json.loads`, header
   parsing) are low.
   Violation: both altitudes in the same body — e.g. `line.split(",", 2)` three lines
   from a business decision. Cite the two lines.

3. **Do block comments narrate sections inside a function body?**
   Detect-grep: `^\s+# `
   Detection: hits within function bodies (not the docstring under the `def`, not a
   `# noqa`, `# type: ignore`, or `# ty: ignore` directive).
   Violation: a comment naming what the next block does — each is a candidate
   extraction point; the fix is a function named after the comment. Quote each
   comment's text with its line: the comment is the evidence and the function's name.

4. **Do boolean flags track state across a loop?**
   Detect-grep: `^\s+[a-z_]+(, *[a-z_]+)* = (False|True)(, *(False|True))*$`
   Detection: hits near `for` and `while` loops; look for flags set inside the loop and read after it, and for
   a `for`/`else` whose `break` is the flag in disguise.
   Violation: flag-driven loops — a collection/domain type should absorb the loop
   (see `../examples/storify-leaf-type.md`).

5. **Does any function name lie about side effects?**
   Detect-grep: `^\s*def (parse|validate|is|get)_[a-z_]*\(|^\s*@property$`
   Detection: for each `parse_*`/`validate_*`/`is_*`/`get_*` function in the diff
   and each `@property`, check the body for assignments to `self.` attributes or to
   a parameter's attributes or elements.
   Violation: a read-sounding name that mutates — rename to a mutating verb or split
   the query from the mutation; a mutating `@property` is the same finding with a
   worse disguise.
