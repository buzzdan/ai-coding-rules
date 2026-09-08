---
# recall: the report names at least one file of this plant by basename.
# ids: R12.Q1.leaked-internals
type: regex
pattern: '(cache\.go|grants\.go|schedule\.go|snapshot_service\.go)'
match: contains
target: last_message
---
