---
# gochecknoglobals routes to R8 (same line, so skill text echoed in tool results cannot satisfy it)
type: regex
pattern: 'gochecknoglobals[^\n]{0,240}\bR8\b'
match: contains
target: trace
---
