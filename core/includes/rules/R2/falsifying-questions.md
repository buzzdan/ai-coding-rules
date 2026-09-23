The detection below names what to search for; build each search over the language's
source files (`{{.SrcGlob}}`), excluding test files, with the repository's own grep
or ripgrep, and read the hits.

1. **Can the type exist in an invalid state?**
   Detection: for each new/changed type with invariants, search for literal
   construction outside its own file (the type's name followed by the language's
   literal or constructor-call syntax, in non-test files); check whether
   invariant-bearing fields are public.
   Violation: any literal-construction site or public invariant-bearing field gives
   callers a path around the constructor.

2. **Do methods re-check what the constructor should guarantee?**
   Detection: in the changed files, find conditionals inside method bodies that test
   the receiver's own fields for the missing value or for emptiness (`if self.repo is
   {{.Nil}}`, `if len(this.items) == 0`).
   Violation: a method validating its own receiver's fields — the check belongs in
   the constructor. Decide which fix by asking whether the field is required or
   optional: a required collaborator is rejected in the constructor (Hoist method
   checks); an optional one (logger, sink, clock, metrics) gets a Null Object
   default there instead (Introduce Null Object, R11) — name both moves in the
   finding when the code does not say which the field is.

3. **Does a constructor re-validate a composed self-validating type?**
   Detection: read each `NewX`/`ParseX` in the diff; for every parameter whose type
   has its own constructor, search the body for checks on that parameter.
   Violation: re-validating a value that could only ever exist valid.

4. **Does the type rely on upstream validation?**
   Detection: search the source files for `caller must`, `assumes valid`,
   `already validated`, `defensive` and `re-check`; also flag public fields consumed
   by logic in a package or module that defines no constructor for the type.
   Violation: any invariant enforced — or merely documented — outside the type
   itself; a value re-validated after the point that validated it (a "defensive
   re-check") is the same finding, the invariant living in two places and in neither
   type.

5. **Does anything return or accept the missing value as a value?**
   Detection: in the changed files, find returns of the language's missing value
   (`return {{.Nil}}`, and a missing value paired with a "no error" result) — exempt
   the failure position of an error result and a legitimately optional return type
   declared as such.
   Violation: the missing value returned for a non-error result, or a function
   checking a parameter for the missing value instead of the value being guaranteed
   by construction.

6. **Does any call site pass the missing value as a non-error argument?**
   Detection: in the changed files, find call sites with the missing value as an
   argument (`({{.Nil}},`, `, {{.Nil}})`) — exempt error positions, comparisons
   (`== {{.Nil}}`, `is {{.Nil}}`), and standard-library idioms where the missing
   value is the documented sentinel (a bodiless request, marshaling an empty
   collection).
   Violation: the missing value passed where a value is expected. Q5 catches the
   return side and Q2 catches the callee that defends; this catches the caller when
   the callee does neither and simply crashes later. Fix on the callee's side: make
   the missing value unrepresentable — a concrete non-optional parameter, a
   validating constructor that rejects it (see the UserService example above), or,
   for an optional collaborator, a Null Object default so the caller never has a
   reason to pass it (`newReporter(sink, {{.Nil}}, {{.Nil}})` is the smell; R11).
