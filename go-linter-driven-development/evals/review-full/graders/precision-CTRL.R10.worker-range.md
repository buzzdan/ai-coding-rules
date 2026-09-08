---
# control CTRL.R10.worker-range: healthy code that must draw no finding; its symbol must not
# appear anywhere in the report (a mention IS the false positive).
type: regex
pattern: 'range jobs'
match: not_contains
target: last_message
---
