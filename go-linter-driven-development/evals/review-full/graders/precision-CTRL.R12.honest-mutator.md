---
# control CTRL.R12.honest-mutator: healthy code that must draw no finding; its symbol must not
# appear anywhere in the report (a mention IS the false positive).
type: regex
pattern: 'drain\(\)'
match: not_contains
target: last_message
---
