1. **Is the same discriminator inspected in more than one place?**
   Detection: list discriminators in the diff —
   `grep -nE 'match [a-zA-Z_.]+\.(type|kind|status|mode|channel|format|level)\b' $(git diff --name-only -- '*.py')`
   and if-chain forms `grep -nE 'if [a-zA-Z_.]+\.(type|kind|status|mode|channel|format|level) ==' ...`;
   then count each across the package: `grep -rnE 'match .*\.<field>|\.<field> ==|\.<field> in \(' --include='*.py' . | wc -l`.
   A `dict` of callables keyed by the field is a dispatch site too — the healthy
   one when it is the only one; a `.get(kind, fallback)` on such a dict deep in
   logic is Q3's default arm in another spelling.
   Violation: ≥2 sites inspecting one discriminator — the decision has no single
   owner. Route first to Strategy Map (a `dict[Kind, Handler]` filled once at the
   boundary), then to Interface Dispatch (a `Protocol` with one class per variant)
   when the variants carry state or several behaviors, and to
   `functools.singledispatch` only when the discriminator is the argument's own
   class.

2. **Does a type switch dispatch on concrete types outside a boundary?**
   Detection: `grep -rnE 'isinstance\([a-zA-Z_.]+, [A-Z]|case [A-Z][A-Za-z]*\(' --include='*.py' .` —
   an `isinstance` chain or a `match` with class patterns; for each hit, is it in a
   `parse`/decoder/boundary adapter, or in business logic?
   Violation: a type switch in domain logic whose cases call variant-specific
   behavior or unpack the variants' fields — the behavior belongs on the variants.
   A switch over a `Protocol` or `ABC` the *same package* owns is a violation even
   at a single site and even in a converter: the decision was already made at
   construction, and a method on each class gives the completeness proof a switch
   can't (`../examples/switch-to-polymorphism.md`). The boundary exemption applies
   only when the output format belongs to a *different* package than the cased
   types (that example's boundary counter) — there, the finding is limited to
   shrinking the switch to pure dispatch. `except` clauses matching exception
   types, and decoding foreign JSON into your own types, are not this pattern.

3. **Does a `case _:` (or trailing `else`) handle "unknown kind" away from the boundary?**
   Detection: for each `match` found in Q1, read the `case _:` arm; for each
   if-chain, the trailing `else`; for each strategy dict, any `.get(k, default)`.
   Violation: a `case _:` that raises `ValueError("unknown kind")`, logs, or
   returns a fallback deep in the call graph — the maybe-unknown concept leaked past
   construction; dispatch should have been chosen at `parse`. The one `case _:`
   that is not a finding is `case _: assert_never(x)` closing a `match` over an
   `Enum` or a `Literal`: it is the completeness proof mypy checks, not a default.
   A `match` over an `Enum` with no such arm is incomplete silently — ruff has no
   exhaustiveness rule, and mypy checks only when `assert_never` asks it to — so
   the missing arm is itself a finding under Keep the Single Exhaustive Switch.

4. **Does a boolean parameter select between behaviors?**
   Detection: `grep -nE 'def .*\(.*\b[a-z_]+: bool' $(git diff --name-only -- '*.py')`,
   and ruff `FBT001` (boolean positional parameter) / `FBT003` (boolean positional
   call argument) where the repository enables them; check whether the function
   branches on the flag near the top.
   Violation: a positional boolean parameter is always the finding — the lint-fixer
   makes it keyword-only (`def send(a: Alert, *, dry_run: bool = False)`), which is
   the mechanical half. A keyword-only boolean stays when its two branches share
   their body and differ in one step; when they share little, Split Flag Argument
   into two named functions.

5. **Inverse — is a NEW dispatch abstraction in the diff unearned?**
   Detection: for each new `Protocol`/ABC hierarchy, strategy dict or
   `singledispatch` in the diff, count production implementations/entries and the
   number of sites the old conditional occupied (`git log -p` or the pre-diff file).
   Violation: one switching site with trivial variance replaced by a class
   hierarchy — score it (R1 scorecard); if LOW, the finding is the *extraction*, and
   the fix is Keep the Single Exhaustive Switch: one `match` over the `Enum`, closed
   by `case _: assert_never(x)`. A Protocol whose second implementation exists only
   in tests is an R6 violation, not a dispatch win.
