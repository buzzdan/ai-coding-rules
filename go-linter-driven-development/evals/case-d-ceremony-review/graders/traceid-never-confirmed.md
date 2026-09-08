---
type: regex
pattern: 'CONFIRMED \(score[^\n]*TraceID'
match: not_contains
target: last_message
---
