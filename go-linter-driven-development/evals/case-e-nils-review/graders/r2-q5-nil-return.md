---
type: regex
pattern: '(reporter|catalog|wire)\.go:[0-9]+.{0,500}\bQ5\b'
flags: s
match: contains
target: last_message
---
