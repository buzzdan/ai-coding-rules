---
# recall: the report names at least one file of this plant by basename.
# ids: R1.lint.run-loop-dupl
type: regex
pattern: '(snapshot_service\.go|sync_service\.go)'
match: contains
target: last_message
---
