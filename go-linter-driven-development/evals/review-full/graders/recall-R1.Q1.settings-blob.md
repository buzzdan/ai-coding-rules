---
# recall: the report names at least one file of this plant by basename.
# ids: R1.Q1.settings-blob
type: regex
pattern: '(job\.go|scheduler\.go|device_service\.go|snapshot_service\.go)'
match: contains
target: last_message
---
