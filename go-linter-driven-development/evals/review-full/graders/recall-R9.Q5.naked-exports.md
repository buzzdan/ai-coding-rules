---
# recall: the report names at least one file of this plant by basename.
# ids: R9.Q5.naked-exports
type: regex
pattern: '(alert\.go|job\.go|snapshot\.go|tags\.go|job_kind\.go|validate\.go)'
match: contains
target: last_message
---
