---
# control CTRL.R1.trace-id-string: healthy code that must draw no finding; its symbol must not
# appear anywhere in the report (a mention IS the false positive).
type: regex
pattern: 'TraceID'
match: not_contains
target: last_message
---
