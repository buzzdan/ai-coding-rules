---
type: regex
pattern: 'CONFIRMED \(score[^\n]*(type Version\b|Version type|Version wrapper|Domain Type:? ?`?Version\b)'
match: not_contains
target: last_message
---
