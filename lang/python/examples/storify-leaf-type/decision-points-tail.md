2. **Honest naming was part of the refactor, not polish.** Renaming
   `_parse_*` → `_align_*` changed what readers expect the function to do; the
   copy-paste logging bug in the before code is the kind of defect dishonest names
   incubate.
3. **This is real shipped code, not an ideal.** The developer stopped here, and two
   improvements remain on the table:
   - **R2 is not fully paid.** `IPConfig` is a mutable dataclass with a separate
     `validate()` that `align_ips` must remember to call — validation the type does
     not own. The stricter move: make collection the constructor, a
     `IPConfig.collect(addresses)` classmethod that raises on an empty result and
     returns a `frozen=True` instance, so `validate()` disappears. Then an invalid
     `IPConfig` cannot reach `align_ips` at all (see
     `../rules/R2-self-validating-types.md`).
   - **The IP strings are still primitives.** `ip4: str` re-checks emptiness at
     each use; an `ipaddress.IPv4Address | None` field, or a small type around it,
     would delete those checks. Score it before wrapping
     (`../rules/R1-primitive-obsession.md`).

   Good refactoring knows when to stop — but a review citing this case should name
   these as the next iterations, not treat the shipped state as the ceiling.
