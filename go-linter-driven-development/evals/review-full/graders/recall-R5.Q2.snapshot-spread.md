---
# recall: the report names at least one file of this plant by basename.
# ids: R5.Q2.snapshot-spread
type: regex
pattern: '(snapshot_service\.go|snapshot\.go|registry\.go)'
match: contains
target: last_message
---
