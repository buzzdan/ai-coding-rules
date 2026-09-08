---
# control CTRL.R8.compile-time-check: healthy code that must draw no finding; its symbol must not
# appear anywhere in the report (a mention IS the false positive).
type: regex
pattern: '_ Store = \(\*FileRepo\)'
match: not_contains
target: last_message
---
