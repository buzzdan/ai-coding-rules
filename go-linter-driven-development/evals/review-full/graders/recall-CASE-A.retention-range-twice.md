---
# recall: the report names at least one file of this plant by basename.
# ids: CASE-A.retention-range-twice
type: regex
pattern: '(policy\.go|config\.go)'
match: contains
target: last_message
---
