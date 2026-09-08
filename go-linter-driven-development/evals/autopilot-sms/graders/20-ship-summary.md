---
type: llm
criteria: The final message is a Phase 5 ship summary that reports (1) the test result — tests green, with the command or a pass statement; (2) the lint result — lint green / LINT STATUS green from the full lint run; (3) the review delta — what @pre-commit-review found and what was fixed, deferred or remained; and (4) the list of files changed. All four must be present; a summary that only describes the feature, or that reports tests or lint as failing, is FAIL.
focus: last_message
---
Score PASS only when each of the four items is explicitly present:

1. Tests: a statement that the test suite passes (e.g. "task test green",
   "go test ./... ok", "all N tests pass"). A claim that tests were not run, or
   that some fail, is FAIL.
2. Lint: a statement that lint is green after the lint-fixer phase (e.g. "task
   lint clean", "LINT STATUS: green", "0 issues"). Pending escalations that were
   never resolved are FAIL.
3. Review delta: mention of the pre-commit review's outcome — findings fixed,
   deferred (with a reason), or "clean" — not merely that a review happened.
4. Files changed: an enumerated list or table of the files added/modified (a
   commit message alone does not satisfy this).

A suggested commit message is welcome but not required. Ignore formatting;
judge content. Do not reward length.
