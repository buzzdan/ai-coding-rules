---
type: regex
pattern: 'R2 \| \S*report/\w+\.go:[0-9]+ \|.{0,500}\bQ5\b'
flags: s
match: contains
target: last_message
---
