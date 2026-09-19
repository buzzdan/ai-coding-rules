2. **Honest naming was part of the refactor, not polish.** Renaming
   `parse*` → `align*` changed what readers expect the function to do; the
   copy-paste logging bug in the before code is the kind of defect dishonest names
   incubate.
3. **This is real shipped code, not an ideal.** The developer stopped here, and two
   improvements remain on the table:
   - **R2 is not fully paid.** `IPConfig` has exported fields and a separate
     `Validate()` that `AlignIPs` must remember to call — validation the type does
     not own. The stricter move: make collection the constructor,
     `collectIPConfigFrom(addresses) (IPConfig, error)`, fold `Validate` into it,
     and unexport the fields behind accessors. Then an invalid `IPConfig` cannot
     reach `AlignIPs` at all (see `../rules/R2-self-validating-types.md`).
   - **The IP strings are still primitives.** `IP4 string` re-checks emptiness at
     each use; a `netip.Addr`-backed type would delete those checks. Score it before
     wrapping (`../rules/R1-primitive-obsession.md`).

   Good refactoring knows when to stop — but a review citing this case should name
   these as the next iterations, not treat the shipped state as the ceiling.
