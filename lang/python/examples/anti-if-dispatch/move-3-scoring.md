A dispatch-happy reading says: three variants, extract a `Severity` protocol with
`Info`, `Warning`, `Critical` classes. Score it before moving (R1 scorecard, via the
over-abstraction skeptic):

- Duplication of the discriminator: **1 site** (grep `match .*severity` → one hit) — +0
- Behavioral variance: one method, returns a constant string — trivial — +0
- Would the protocol be earned (R6)? Three implementations, but each is an empty
  class wrapping one literal — ceremony
