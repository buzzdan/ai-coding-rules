---
# control CTRL.R3.guard-clauses: healthy code that must draw no finding; its symbol must not
# appear anywhere in the report (a mention IS the false positive).
type: regex
pattern: 'ctx\.Err\(\)'
match: not_contains
target: last_message
---
