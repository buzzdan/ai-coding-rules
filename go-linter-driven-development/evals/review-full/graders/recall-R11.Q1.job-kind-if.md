---
# recall: the report names at least one file of this plant by basename.
# ids: R11.Q1.job-kind-if
type: regex
pattern: '(scheduler\.go|snapshot_service\.go|job\.go)'
match: contains
target: last_message
---
