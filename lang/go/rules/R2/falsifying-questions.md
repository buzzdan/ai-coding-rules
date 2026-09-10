1. **Can the type exist in an invalid state?**
   Detection: for each new/changed type with invariants,
   `grep -rn '<Type>{' --include='*.go' . | grep -v _test.go` for literal
   construction outside its own file; check whether invariant-bearing fields are
   exported.
   Violation: any literal-construction site or exported invariant-bearing field
   gives callers a path around the constructor.

2. **Do methods re-check what the constructor should guarantee?**
   Detection: `grep -nE 'if [a-z][a-zA-Z]*\.[a-zA-Z]+ == nil|if len\([a-z][a-zA-Z]*\.[a-zA-Z]+\) == 0' <changed files>`
   inside method bodies.
   Violation: a method validating its own receiver's fields — the check belongs in
   the constructor.

3. **Does a constructor re-validate a composed self-validating type?**
   Detection: read each `NewX`/`ParseX` in the diff; for every parameter whose type
   has its own constructor, grep the body for checks on that parameter.
   Violation: re-validating a value that could only ever exist valid.

4. **Does the type rely on upstream validation?**
   Detection: `grep -rn 'caller must\|assumes valid\|already validated' --include='*.go' .`;
   also flag exported fields consumed by logic in a package that defines no
   constructor for the type.
   Violation: any invariant enforced — or merely documented — outside the type
   itself.

5. **Does anything return or accept nil as a value?**
   Detection: `grep -nE 'return nil$|return nil, nil' <changed files>` — exempt
   `return nil, err` and `return val, nil`.
   Violation: nil returned for a non-error value, or a function nil-checking a
   parameter instead of the value being guaranteed by construction.

6. **Does any call site pass a nil literal as a non-error argument?**
   Detection: `grep -nE '\(nil[,)]|, nil[,)]' <changed files>` — exempt error
   positions (`return X, nil`), comparisons (`== nil`, `!= nil`), and stdlib
   idioms where nil is the documented sentinel (`http.NewRequest(..., nil)` for
   a bodyless request, marshaling a nil slice/map).
   Violation: nil passed where a value is expected. Q5 catches the return side
   and Q2 catches the callee that defends; this catches the caller when the
   callee does neither and simply panics later. Fix on the callee's side: make
   nil unrepresentable — a concrete non-pointer parameter, or a validating
   constructor that rejects nil (see the UserService example above).
