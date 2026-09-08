---
# control CTRL.R2.snapshot-repository: healthy code that must draw no finding; its symbol must not
# appear anywhere in the report (a mention IS the false positive).
type: regex
pattern: 'NewRepository\(|now == nil'
match: not_contains
target: last_message
---
