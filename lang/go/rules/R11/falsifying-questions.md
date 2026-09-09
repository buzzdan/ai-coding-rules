
1. **Is the same discriminator inspected in more than one place?**
   Detection: list discriminators in the diff —
   `grep -nE 'switch [a-zA-Z_.]+\.(Type|Kind|Status|Mode|Channel|Format|Level)\b' $(git diff --name-only -- '*.go')`
   and if-chain forms `grep -nE 'if [a-zA-Z_.]+\.(Type|Kind|Status|Mode|Channel|Format|Level) ==' ...`;
   then count each across the package: `grep -rn 'switch .*\.<Field>' --include='*.go' . | wc -l` (plus `== ` comparisons on the same field).
   Violation: ≥2 sites inspecting one discriminator — the decision has no single
   owner; route to Interface Dispatch or Strategy Map.

2. **Does a type switch dispatch on concrete types outside a boundary?**
   Detection: `grep -rn 'switch .* := .*\.(type)' --include='*.go' .` — for each hit,
   is it in a `ParseX`/decoder/boundary adapter, or in business logic?
   Violation: a type switch in domain logic whose cases call variant-specific
   behavior or unpack the variants' fields — the behavior belongs on the variants.
   A switch over an interface the *same package* owns is a violation even at a
   single site and even in a converter: the decision was already made at
   construction, and interface satisfaction gives the completeness proof a
   switch can't (`../examples/switch-to-polymorphism.md`). The boundary exemption
   applies only when the output format belongs to a *different* package than the
   cased types (that example's boundary counter) — there, the finding is limited
   to shrinking the switch to pure dispatch. `errors.As`/`errors.Is` chains and
   decode/unmarshal of foreign types are not this pattern.

3. **Does a `default:` (or trailing `else`) handle "unknown kind" away from the boundary?**
   Detection: for each switch found in Q1, check the `default` arm for
   `errors.New`/`fmt.Errorf`/panic on an unknown-kind message.
   Violation: unknown-kind errors deep in the call graph — the maybe-unknown concept
   leaked past construction; dispatch should have been chosen at `ParseX`.

4. **Does a boolean parameter select between behaviors?**
   Detection: `grep -nE 'func .*\(.*\b(is|use|with|enable|skip)[A-Za-z]* bool' $(git diff --name-only -- '*.go')`;
   check whether the function branches on it near the top.
   Violation: a flag argument whose branches share little code — Split Flag Argument.

5. **Inverse — is a NEW dispatch abstraction in the diff unearned?**
   Detection: for each new interface/strategy map in the diff, count production
   implementations/entries and the number of sites the old conditional occupied
   (`git log -p` or the pre-diff file).
   Violation: one switching site with trivial variance replaced by an interface —
   score it (R1 scorecard); if LOW, the finding is the *extraction*, and the fix is
   Keep the Single Exhaustive Switch. An interface whose second implementation exists
   only in tests is an R6 violation, not a dispatch win.
