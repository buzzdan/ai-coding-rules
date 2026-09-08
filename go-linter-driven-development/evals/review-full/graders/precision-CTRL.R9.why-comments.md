---
# control CTRL.R9.why-comments: healthy code that must draw no finding; its symbol must not
# appear anywhere in the report (a mention IS the false positive).
type: regex
pattern: 'store behind|can be joined later|races a manual cleanup'
match: not_contains
target: last_message
---
