1. **Does a method return an internal slice or map by reference?**
   Detection: for each type in the diff with a validating constructor, list its
   slice/map fields (`grep -A8 'type <X> struct' <file>`), then
   `grep -nE 'return [a-z][a-zA-Z]*\.(<field1>|<field2>)$' <file>` — a bare
   `return x.field` with no `Clone`/copy/iterator around it.
   Violation: an internal reference escapes a validated type — Copy on the Way Out.

2. **Does a constructor store a caller-provided slice/map without copying?**
   Detection: inside each `ParseX`/`NewX` in the diff, check the struct literal for a
   slice/map field assigned directly from a parameter identifier
   (`grep -nE '<param>\s*[,}]' within the return literal).
   Violation: the type's state aliases memory the caller still holds — Copy on the
   Way In. (A collection built inside the constructor, like `dedupeAndValidate`'s
   result, is fine — no one else holds it.)

3. **Does one method both return domain data and mutate the receiver?**
   Detection: for each changed method with a non-error return value,
   grep its body for assignments to receiver fields (`<recv>.<field> =`,
   `append(<recv>.` ).
   Violation: a query/modifier hybrid where any call site discards the return value
   or calls it only for the effect — Separate Query from Modifier. (If every caller
   genuinely needs both halves atomically — `sync`-guarded pop-and-report — it is
   one operation; name it as a mutator per R3 and move on.)

4. **Can a validated type be mutated around its constructor?**
   Detection: `grep -rnE 'func \([a-z][a-zA-Z]* \*?[A-Z][a-zA-Z]*\) Set[A-Z]' --include='*.go' .`
   for setters; for each hit, does the receiver type have a `ParseX`/`NewX` that
   validates, and does the setter re-check?
   Violation: a setter that assigns unchecked on a constructor-validated type —
   Remove Setting Method. (Exported mutable fields on such types are R2's Q1.)

5. **Is one variable reassigned to mean something different?**
   Detection: read each changed function; for every reassignment (`x = ...` after
   `x := ...`), ask whether the right-hand side computes the same concept.
   Violation: two meanings under one name — Split Variable; cite both assignments.

6. **Inverse — does the diff copy defensively where no alias escapes?**
   Detection: for each new `slices.Clone`/`maps.Clone`/manual copy loop in the diff,
   trace the copied value: does the source or the copy ever cross a function
   boundary or outlive the call?
   Violation: cloning data that provably never escapes, or copying per-iteration in
   a loop the profile cares about — ceremony; delete the copy and note why sharing
   is safe.
