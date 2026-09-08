---
# control CTRL.R2.window-plan: healthy code that must draw no finding; its symbol must not
# appear anywhere in the report (a mention IS the false positive).
type: regex
pattern: 'ParseWindow'
match: not_contains
target: last_message
---
