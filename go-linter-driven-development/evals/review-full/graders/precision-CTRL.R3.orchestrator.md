---
# control CTRL.R3.orchestrator: healthy code that must draw no finding; its symbol must not
# appear anywhere in the report (a mention IS the false positive).
type: regex
pattern: 'Prune'
match: not_contains
target: last_message
---
