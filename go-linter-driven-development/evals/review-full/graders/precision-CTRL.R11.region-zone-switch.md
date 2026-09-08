---
# control CTRL.R11.region-zone-switch: healthy code that must draw no finding; its symbol must not
# appear anywhere in the report (a mention IS the false positive).
type: regex
pattern: 'Zone\(\)'
match: not_contains
target: last_message
---
