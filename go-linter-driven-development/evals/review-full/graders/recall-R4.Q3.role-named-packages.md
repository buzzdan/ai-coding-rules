---
# recall: the report names at least one file of this plant by basename.
# ids: R4.Q3.role-named-packages
type: regex
pattern: '(strings\.go|time\.go|constants\.go)'
match: contains
target: last_message
---
