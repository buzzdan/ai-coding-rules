- **The drift already happened.** `validRecipient` returns `false` for `"pagerduty"`
  — not by decision, but because the second copy of the switch was not in view when
  the third channel landed. Duplicated discriminators drift the same way duplicated
  validation predicates drift (R1's Q2).
- **Adding SMS is a scavenger hunt.** Three known sites, plus whatever a grep misses
  (test helpers, a metrics label formatter). The compiler flags none of them: an
  if-chain has no completeness, and a switch with a `default` swallows the new case
  silently.
- **"Unknown channel" leaks everywhere.** Every switching site carries the
  `default:`/fall-through arm, so every function's signature and tests carry the
  maybe-unknown concept — the behavioral twin of R1's maybe-invalid port.
- **Nothing unit-tests in isolation.** Slack's recipient rule is only reachable by
  driving `validRecipient` with a fully built `Alert`.
