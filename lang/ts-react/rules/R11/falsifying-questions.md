1. **Is the same discriminator inspected in more than one place?**
   Detection: list discriminators in the diff —
   `grep -nE 'switch \([a-zA-Z_.]+\.(type|kind|status|mode|channel|format|level)\)' $(git diff --name-only -- '*.ts' '*.tsx')`
   and if-chain forms `grep -nE "if \([a-zA-Z_.]+\.(type|kind|status|mode|channel|format|level) === '" ...`;
   then count each across the repository: `grep -rnE "switch \(.*\.<field>\)|\.<field> === '" --include='*.ts' --include='*.tsx' --exclude-dir=node_modules . | wc -l`.
   A `Record<Kind, …>` of handlers or components keyed by the field is a dispatch
   site too — the healthy one when it is the only one; a `MAP[kind] ?? fallback`
   deep in logic is Q3's default arm in another spelling.
   Violation: ≥2 sites inspecting one discriminator — the decision has no single
   owner. Route first to Strategy Map (a `Record<Kind, Handler>` — for rendering, a
   `Record<Kind, ComponentType<…>>` — filled once at the boundary), then to
   Interface Dispatch (an interface with one object per variant) when the variants
   carry state or several behaviours, and to a class hierarchy last.

2. **Does a type switch dispatch on concrete types outside a boundary?**
   Detection: `grep -rnE "instanceof [A-Z]|'[a-zA-Z]+' in [a-zA-Z_.]+\)|typeof [a-zA-Z_.]+ === '(string|number|object)'" --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .` —
   an `instanceof` chain, an `in` chain or a `typeof` chain; for each hit, is it in
   a `parse*`/type-guard/boundary adapter, or in business logic or a render?
   Violation: a type switch in domain logic whose cases call variant-specific
   behavior or unpack the variants' fields — the behavior belongs on the variants.
   An `instanceof` chain over classes the *same module* owns is a violation even
   at a single site and even in a converter: the decision was already made at
   construction, and a method on each class (or an entry per variant in the
   `Record`) gives the completeness proof a chain can't
   (`../examples/switch-to-polymorphism.md`). The boundary exemption applies only
   when the output format belongs to a *different* package than the cased types
   (that example's boundary counter) — there, the finding is limited to shrinking
   the switch to pure dispatch. Type guards in `src/types/typeGuards.ts` narrowing
   `unknown` at the API boundary, `catch` blocks narrowing an `error`, and
   `instanceof` on a dependency's classes are not this pattern.

3. **Does a `default:` (or trailing `else`) handle "unknown kind" away from the boundary?**
   Detection: for each `switch` found in Q1, read the `default` arm; for each
   if-chain, the trailing `return`; for each `Record` lookup, any `?? fallback`.
   Violation: a `default: return null` in a render switch, a `default: throw new
   Error('unknown kind')`, a logged fallback deep in the call graph — the
   maybe-unknown concept leaked past construction; dispatch should have been chosen
   at `parse*`. The one `default` that is not a finding is `default: return
   assertNever(x)` (or `x satisfies never`) closing a switch over a union: it is the
   completeness proof `tsc` checks, not a default. A switch over a union with no
   such arm is incomplete silently — a missing case falls through to `undefined`
   unless `@typescript-eslint/switch-exhaustiveness-check` is configured — so the
   missing arm is itself a finding under Keep the Single Exhaustive Switch.

4. **Does a boolean parameter select between behaviors?**
   Detection: `grep -nE '\b(is|has|show|hide|use|with|enable|skip|as)[A-Z][A-Za-z]*\??: boolean' $(git diff --name-only -- '*.ts' '*.tsx')`
   for props and options typed `boolean`, and `grep -nE 'function [a-zA-Z]+\([^)]*: boolean' ...`
   for positional flags; check whether the function or component branches on the
   flag near the top.
   Violation: a positional boolean parameter is always the finding — the lint-fixer
   moves it into an options object (`send(alert, { dryRun: true })`), which is the
   mechanical half. A named boolean stays when its two branches share their body
   and differ in one step; when they share little, Split Flag Argument into two
   named functions. Boolean props are the component form: three or more on one
   component, or an `isLoading`/`isError`/`isEmpty` triplet, is the same finding —
   two components, or a `status`/`variant` union when the flags exclude each other.

5. **Inverse — is a NEW dispatch abstraction in the diff unearned?**
   Detection: for each new interface with several implementations, class
   hierarchy, `Record` map or context introduced "for dispatch" in the diff, count
   production implementations/entries and the number of sites the old conditional
   occupied (`git log -p` or the pre-diff file).
   Violation: one switching site with trivial variance replaced by a hierarchy —
   score it (R1 scorecard); if LOW, the finding is the *extraction*, and the fix is
   Keep the Single Exhaustive Switch: one `switch` over the union, closed by
   `default: return assertNever(x)`. An interface whose second implementation
   exists only in tests is an R6 violation, not a dispatch win.
