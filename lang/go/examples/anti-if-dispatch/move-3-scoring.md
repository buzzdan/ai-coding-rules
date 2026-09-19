A dispatch-happy reading says: three variants, extract `type Severity interface`
with `Info`, `Warning`, `Critical` types. Score it before moving (R1 scorecard, via
the over-abstraction skeptic):

- Duplication of the discriminator: **1 site** (grep `switch .*Severity` → one hit) — +0
- Behavioral variance: one method, returns a constant string — trivial — +0
- Would the interface be earned (R6)? Three implementations, but each is an empty
  struct wrapping one literal — ceremony
