---
# control CTRL.R6.store-interface: healthy code that must draw no finding; its symbol must not
# appear anywhere in the report (a mention IS the false positive).
type: regex
pattern: 'Store interface'
match: not_contains
target: last_message
---
