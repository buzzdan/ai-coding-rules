---
# recall: the report names at least one file of this plant by basename.
# ids: R5.Q1.role-layers
type: regex
pattern: '(trace\.go|device_service\.go|device\.go|store\.go)'
match: contains
target: last_message
---
