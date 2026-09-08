---
# pre-commit-review step 1: every //nolint directive in scope is its own finding
type: regex
pattern: 'nolint'
match: contains
target: last_message
---
