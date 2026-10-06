1. **Does a method return an internal array, Map or Set by reference?**
   Detection: for each type in the diff with a validating factory, list its
   collection fields (`grep -nE '(private|readonly) +[a-zA-Z_]+ *: *([A-Za-z]+\[\]|Array<|Map<|Set<)' <file>`), then
   `grep -nE 'return this\.[a-zA-Z_]+$' <file>` — a bare `return this.items` whose
   return type is a mutable `T[]`/`Map`/`Set`, with no spread, `Array.from`, `new
   Map(…)`, `readonly` return type or iterator around it; a `get items()` accessor
   that returns the field is the same hit with a nicer name, and so is a hook that
   returns the array it keeps in a ref or in module state.
   Violation: an internal reference escapes a validated type — Copy on the Way Out
   (a `readonly Permission[]` return type, `[...this.items]`, a `ReadonlyMap` built
   with `new Map(this.byId)`, a generator).

2. **Does a constructor store a caller-provided array or Map without copying?**
   Detection: inside each constructor and static `parse` in the diff, check for a
   collection field assigned directly from a parameter (`this.items = items`; a
   parameter property `private readonly items: Item[]`). In a component, a prop
   array or object stored into `useRef`/`useState` and mutated later is the same
   alias.
   Violation: the type's state aliases memory the caller still holds — Copy on the
   Way In (`[...items]`, `new Map(byId)`). A field typed `readonly T[]` makes the
   no-mutation half part of the contract but not the no-alias half: the caller
   still holds the mutable original, so the copy stays. (A collection built inside
   the factory, like `dedupeAndValidate`'s result, is fine — no one else holds it.)

3. **Does one method both return domain data and mutate the receiver?**
   Detection: for each changed method with a return type other than `void`, grep
   its body for assignments to fields (`this\.[a-zA-Z_]+ =`,
   `this\.[a-zA-Z_]+\.(push|splice|sort|reverse|set|delete|clear)\(`); for each
   `select` option, selector or formatter over query data, grep for an in-place
   `.sort(`, `.reverse(` or `.splice(` on data the function did not build — the
   query cache is the receiver it mutates. `no-param-reassign` marks the writes to
   parameters; the in-place sort of someone else's data is review-only.
   Violation: a query/modifier hybrid where any call site discards the return value
   or calls it only for the effect — Separate Query from Modifier; a selector that
   sorts in place becomes `toSorted(…)`. (If every caller genuinely needs both
   halves atomically — a pop-and-report on a queue — it is one operation; name it as
   a mutator per R3 and move on.)

4. **Can a validated type be mutated around its constructor?**
   Detection: `grep -rnE '^\s+set [a-zA-Z_]+\(|^\s+set[A-Z][a-zA-Z]*\([^)]*\): void' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`
   for setters, and for each class or type with a validating `parse` check whether
   its fields are `readonly` (`sonarjs/prefer-read-only-props` is the same check for
   component props); for each hit, does the type validate in its factory, and does
   the setter re-check? In state: `setState((d) => { d.status = x; return d })`
   mutates the previous state and returns the same reference, so React skips the
   render (`react/no-direct-mutation-state` catches the class-component form; the
   hook form is read).
   Violation: a setter, or a mutable field, that assigns unchecked on a
   factory-validated type — Remove Setting Method (and `readonly`, so `port.number
   = 0` fails under `tsc`); an updater that mutates — return a new object
   (`{ ...d, status: x }`) or a reducer that returns new state. (Public mutable
   fields with no factory check at all are R2's Q1.)

5. **Is one variable reassigned to mean something different?**
   Detection: read each changed function; for every `let` that survives
   `prefer-const` (it is reassigned somewhere), including a loop variable reused
   after its loop or an `n` that counted one thing and then another, ask whether the
   right-hand side computes the same concept.
   Violation: two meanings under one name — Split Variable; cite both assignments.

6. **Inverse — does the diff copy defensively where no alias escapes?**
   Detection: for each new `[...x]`, `{ ...x }`, `Array.from`, `new Map(x)`,
   `structuredClone` or manual copy loop in the diff — and each `useMemo(() =>
   [...items], [items])` over a prop — trace the copied value: does the source or
   the copy ever cross a function boundary or outlive the call?
   Violation: cloning data that provably never escapes, or copying on every render
   of a list the profile cares about — ceremony; delete the copy and note why
   sharing is safe. A module-level `const EMPTY_ITEMS: Item[] = []` handed out as a
   default to several callers is the opposite failure — one array shared by every
   call; type it `readonly Item[]` so no caller can push into it.
