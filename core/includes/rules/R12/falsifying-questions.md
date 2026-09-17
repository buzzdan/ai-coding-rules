Build each search over the language's source files (`{{.SrcGlob}}`).

1. **Does a method return an internal list or map by reference?**
   Detection: for each type in the diff with a validating constructor, list its
   collection fields (read the type's declaration), then find in its methods a bare
   `return self.<field>` / `return x.<field>` with no copy, clone or iterator around
   it.
   Violation: an internal reference escapes a validated type — Copy on the Way Out.

2. **Does a constructor store a caller-provided list or map without copying?**
   Detection: inside each `ParseX`/`NewX` in the diff, check the construction for a
   collection field assigned directly from a parameter identifier.
   Violation: the type's state aliases memory the caller still holds — Copy on the
   Way In. (A collection built inside the constructor, like `dedupeAndValidate`'s
   result, is fine — no one else holds it.)

3. **Does one method both return domain data and mutate the receiver?**
   Detection: for each changed method with a non-error return value, search its body
   for assignments to receiver fields (`self.<field> =`, `this.<field> =`, an append
   or push onto a receiver collection).
   Violation: a query/modifier hybrid where any call site discards the return value
   or calls it only for the effect — Separate Query from Modifier. (If every caller
   genuinely needs both halves atomically — a lock-guarded pop-and-report — it is one
   operation; name it as a mutator per R3 and move on.)

4. **Can a validated type be mutated around its constructor?**
   Detection: search the source files for setters on public types (methods named
   `set<Field>`, a property setter, a public mutable field); for each hit, does the
   receiver type have a `ParseX`/`NewX` that validates, and does the setter
   re-check?
   Violation: a setter that assigns unchecked on a constructor-validated type —
   Remove Setting Method. (Public mutable fields on such types are R2's Q1.)

5. **Is one variable reassigned to mean something different?**
   Detection: read each changed function; for every reassignment (`x = ...` after
   `x` was first bound), ask whether the right-hand side computes the same concept.
   Violation: two meanings under one name — Split Variable; cite both assignments.

6. **Inverse — does the diff copy defensively where no alias escapes?**
   Detection: for each new clone, copy or manual copy loop in the diff, trace the
   copied value: does the source or the copy ever cross a function boundary or
   outlive the call?
   Violation: cloning data that provably never escapes, or copying per-iteration in
   a loop the profile cares about — ceremony; delete the copy and note why sharing
   is safe.
