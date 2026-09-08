---
# recall: the report names at least one file of this plant by basename.
# ids: R1.Q3.raw-channel-string
type: regex
pattern: '(alert\.go|channel\.go)'
match: contains
target: last_message
---
