1. **Can the type exist in an invalid state?**
   Detect: judgment
   Detection: for each new/changed type with invariants, read its declaration: an
   `interface` or `type` whose fields are not `readonly`, a class whose constructor
   assigns without checking, or (where the repository has a schema library) a schema
   with no refinement for the field that carries the rule. Then
   `grep -rnE '<Type> = \{|: <Type> = \{|as <Type>\b' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules . | grep -v '\.test\.'`
   for construction sites outside the factory, and
   `grep -rn 'as unknown as' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`
   for the double cast. Literal construction is the hole here: types are erased, so
   an object literal typed `Port` never meets `parsePort`, and the factory is the
   only entry by discipline — every literal outside it and outside tests is a path
   around the constructor. A class with a `private` field and a private constructor
   closes the path for the compiler as well.
   Violation: a mutable field carrying an invariant it never checks, an object
   literal or `as <Type>` outside the factory and tests, or an `apiClient.get<T>()`
   whose `T` is a domain type — each gives callers a path around the constructor.

2. **Do methods re-check what the constructor should guarantee?**
   Detect-grep: `if \(!this\.[a-zA-Z_]+\)|this\.[a-zA-Z_]+ (===|!==) (undefined|null)|this\.[a-zA-Z_]+\?\.|if \(this\.[a-zA-Z_]+\.length === 0\)`
   Detection: hits inside method bodies (not the constructor). The pattern reads
   `this.`; in a hook or component the instance is its props and state, so grep the
   body for each required prop's name — `if (!cluster)` and `cluster?.name` on a
   required prop are the same hits.
   Violation: a method validating its own instance's fields — the check belongs in
   the constructor. Decide which fix by asking whether the field is required or
   optional: a required collaborator is rejected in the constructor (Hoist method
   checks); an optional one (logger, sink, clock, metrics) gets a Null Object
   default there instead (Introduce Null Object, R11) — name both moves in the
   finding when the code does not say which the field is. A field typed
   `X | undefined` on the class is the evidence that the question is asked in every
   method, whether or not each method spells the guard; `?.` spells it in one
   character.

3. **Does a constructor re-validate a composed self-validating type?**
   Detect: judgment
   Detection: read each `parseX`/`createX` factory and class constructor in the
   diff; for every parameter whose type has its own factory or type guard, grep the
   body for checks on that parameter.
   Violation: re-validating a value that could only ever exist valid.

4. **Does the type rely on upstream validation?**
   Detect-grep: `[Cc]aller must|[Aa]ssumes valid|[Aa]lready validated|[Dd]efensive|[Rr]e-?check` files=all
   Detection: also flag mutable fields consumed by logic in a module that defines no
   factory or type guard for the type, and a bare `type DeviceId = string` or a
   brand with no validating constructor standing in for a validated value (both are
   erased; the alias admits every literal and the brand every cast).
   Violation: any invariant enforced — or merely documented — outside the type
   itself; a value re-validated after the point that validated it (a "defensive
   re-check" — a component checking what its prop type promises, a service
   re-parsing what `parseDevice` returned) is the same finding, the invariant living
   in two places and in neither type.

5. **Does anything return or accept `undefined` or `null` as a value?**
   Detect-grep: `return (undefined|null)\s*(//.*)?$|^\s+return$`
   Detection: a bare `return` in a function with a return type counts; read each
   hit's signature and the branch it sits in. Three verdicts:
   - the signature says `: X` and the body returns `null` or `undefined`: `tsc`
     rejects it under `strict`, so the hit arrives silenced — `as X`, a `!`, a
     `@ts-expect-error` — or as `-1`/`''`/`0`: R1 Q4's sentinel, cite it there;
   - the signature says `: X | undefined` and the `undefined` branch is a normal
     absence a caller expects — a `Map.get`, the first match of a `find`, an
     optional property — and every caller narrows it: not a finding. `undefined` is
     TypeScript's declared absence, checked by `strict` at each call site; `null` is
     the wire's absence and stops at the boundary, where the parser maps it to
     `undefined` or to a domain value;
   - the signature says `: X | undefined` (or `| null`) and the branch is a failure
     — malformed input, a broken invariant, a `catch` that returns `null` and turns
     a network error into "not found" — or callers stack `?.`, `??` and `if (!x)`
     because the absence should have been an exception: Separate Failure from
     Absence; `throw` where the failure `return` was, and keep `X | undefined` only
     for the branch that is truly absence.
   Exempt: `: void` procedures, the `undefined` result of a well-typed `.get` or
   `.find`, and a component returning `null` to render nothing. `[X, boolean]` is
   never the fix: it is a comma-ok idiom with a TypeScript spelling.
   Violation: `null`/`undefined` returned where the signature promises a value;
   `undefined` standing in for a failure; or a function guarding a parameter against
   `undefined` instead of the value being guaranteed by construction and by its type.

6. **Does any call site pass `undefined` or `null` as a non-error argument?**
   Detect-grep: `\((undefined|null)[,)]|, (undefined|null)[,)]|: (undefined|null)[,} ]`
   Detection: exempt comparisons (`=== undefined`, `!== null`), and platform idioms
   where the value is the documented "no value" (`JSON.stringify(v, null, 2)`,
   `useRef<T>(null)` for a DOM ref, `createContext<T | undefined>(undefined)` for
   the key whose `useX()` throws outside its provider).
   Violation: `undefined` or `null` passed where a value is expected — `useX(undefined)`,
   `new Reporter(sink, undefined)`. Q5 catches the return side and Q2 catches the
   callee that defends; this catches the caller when the callee does neither and
   throws `TypeError` later. Fix on the callee's side: make the hole unrepresentable
   — a parameter typed `X`, never `X | undefined` or `x?: X` on a required value; a
   constructor whose parameter type rejects it (see the UserService example above);
   or, for an optional collaborator, a Null Object default through destructuring so
   the caller never has a reason to pass `undefined` (R11). An optional callback prop
   (`onOpenEvents?`) is not this finding when the component has a meaning without
   it; it is when every render path guards it, or the component cannot do its job
   without it — then the prop is required. `tsc` makes the typed half of this
   question mechanical: `undefined` passed to an `X` parameter does not compile, so
   the finding survives only where the parameter is typed `X | undefined` or `x?: X`,
   or the code is not type-checked.
