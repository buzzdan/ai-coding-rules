---
type: regex
pattern: '(reporter|catalog|wire)\.go:[0-9]+.{0,500}\bQ6\b'
flags: s
match: contains
target: last_message
---
