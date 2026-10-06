2. **Honest naming was part of the refactor, not polish.** Renaming
   `parseIp*` → `alignIpv*` changed what readers expect the function to do; the
   copy-paste logging bug in the before code is the kind of defect dishonest names
   incubate.
3. **This is real shipped code, not an ideal.** The developer stopped here, and two
   improvements remain on the table:
   - **R2 is not fully paid.** `IPConfig` is a class with public mutable fields and a
     separate `validate()` that `alignIps` must remember to call — validation the
     type does not own. The stricter move: make collection the constructor — a
     `collectIpConfigFrom(addresses)` that throws on an empty result and returns
     a value with `readonly ip4`/`readonly ip6`, so `validate()` disappears. Then an
     invalid `IPConfig` cannot reach `alignIps` at all (see
     `../rules/R2-self-validating-types.md`).
   - **The IP strings are still primitives.** `ip4: string` re-checks emptiness at
     each use; an optional `ip4?: IPv4Address` — `undefined` as the declared absence,
     a branded type built by one validating factory — would delete those checks.
     Score it before wrapping (`../rules/R1-primitive-obsession.md`).

   Good refactoring knows when to stop — but a review citing this case should name
   these as the next iterations, not treat the shipped state as the ceiling.
