- **The drift already happened.** `valid_recipient` returns `False` for
  `"pagerduty"` — not by decision, but because the second copy of the switch was not
  in view when the third channel landed. Duplicated discriminators drift the same way
  duplicated validation predicates drift (R1's Q2).
- **Adding SMS is a scavenger hunt.** Three known sites, plus whatever a grep misses
  (test helpers, a metrics label formatter). Neither ruff nor ty flags any of them:
  an if-chain has no completeness, a `match` on a `str` has nothing to be exhaustive
  over, and a `.get(kind, default)` swallows the new case silently.
- **"Unknown channel" leaks everywhere.** Every switching site carries the
  `case _:`/fall-through arm, so every function's signature and tests carry the
  maybe-unknown concept — the behavioral twin of R1's maybe-invalid port.
- **Nothing unit-tests in isolation.** Slack's recipient rule is only reachable by
  driving `valid_recipient` with a fully built `Alert`.
