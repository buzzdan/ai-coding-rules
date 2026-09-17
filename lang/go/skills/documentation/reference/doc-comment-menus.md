## Godoc Menus

**These are MENUS, not forms** (normative: R9's tiered comment-budget policy —
**1–5 prose lines** scaled to the symbol's role; blank `//` lines, the See-edge, and
short inline examples of 2–4 lines are free). The menus price **exported** API
only — unexported symbols default to no comment at all (R9's visibility
default; special case: one very-high-value line). The WHY is the default
content; the tier caps how much of a menu any one symbol can order:

- **Helper** (small method, plain constructor, obvious accessor) → 0–1 line, or
  nothing; a tiny example only if it clarifies.
- **Contract** (parsing constructor like `ParsePort`, self-validating type, ordinary
  exported API) → 2–3 lines; a dos/don'ts example is free and often earns its place.
- **Crossroads** (entry point, orchestrator, state machine, feature front door) →
  up to 5 lines: WHY, architectural context, use cases.

Overflow never stays inline — it moves to the feature doc; the
`See docs/<feature>.md` edge (kept whenever the doc exists) carries the pointer. A
crossroads that deserves more than 5 lines inline gets an expand recommendation in
the FEATURE report instead of extra lines — a human decides (R9's escape hatch).

What fills the chosen menu lines comes from the [Comment Value Toolbox](#comment-value-toolbox)
above — every prose line must deliver one of its values, in plain English (R9's
three-test standard).

### Package Godoc Menu

Pick only the lines this package needs:

```go
// Package [name] provides [high-level purpose].          <- always (one line)
//
// [1-2 sentences: what problem this solves]              <- usually
//
// Main data flow:                                        <- only if non-obvious
//   Input -> Validation -> Processing -> Output
//
// Core types:                                            <- multi-type packages only
//   - Type1: [key responsibility]
//
// Design decisions:                                      <- only where rationale exists
//   - [Key decision and why]
//
// See docs/[feature].md for architecture and usage.      <- whenever the doc exists
package name
```

**The `doc.go` hatch (R9):** when a package genuinely earns more than the standard
budget — flow sketch, core-types list, and design decisions all pulling their
weight — move the package godoc to a dedicated `doc.go`, bounded at ~20–30 lines.
A package comment inline in a regular file stays within the standard tier budget.

### Type Godoc Menu

Pick per symbol kind (hints above):

```go
// TypeName is [one-line domain meaning].                 <- always
//
// [WHY it exists: rationale, incident, constraint —      <- the default content
//  context the code cannot carry]
//
// Constraints:                                           <- self-validating types
//   - [validation rules, thread-safety guarantees]
//
// Use cases / flow:                                      <- logic-heavy types only
//   [when to reach for it, or a short flow sketch]
//
// Example:                                               <- parsing constructors:
//   p, err := ParsePolicy("3x100ms")  // valid              dos/don'ts inputs
//   _, err = ParsePolicy("0x")        // rejected: zero attempts
//
// See docs/[feature].md for the full picture.            <- whenever the doc exists
type TypeName struct {
    // ...
}
```

### Function Godoc Menu

Only for non-obvious behavior; a small method or plain constructor gets one line, or
nothing:

```go
// FunctionName [does what] for [purpose].                <- always, if documented at all
//
// [Error conditions, non-obvious behavior,               <- only when non-obvious
//  performance characteristics]
//
// See docs/[feature].md#section for the detailed flow.   <- whenever the doc exists
func FunctionName(ctx context.Context, input InputType) (OutputType, error) {
    // ...
}
```

### Testable Example Template

```go
// Example_TypeName demonstrates typical usage of TypeName.
func Example_TypeName() {
    id, _ := NewUserID("usr_123")
    fmt.Println(id)
    // Output: usr_123
}

// Example_TypeName_validation shows validation behavior.
func Example_TypeName_validation() {
    _, err := NewUserID("")
    fmt.Println(err != nil)
    // Output: true
}
```

Testable examples show happy-path usage. Keep simple — complex scenarios belong in
feature docs.
