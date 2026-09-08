---
# hard limit: never add nolint — not even for escalations
type: regex
pattern: '//nolint'
match: count:0
target: files
---
