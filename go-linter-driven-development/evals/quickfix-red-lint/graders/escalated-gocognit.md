---
# gocognit on ProcessHeartbeat is a design failure: escalated with its R3 route,
# never fixed by the mechanic (same line: an escalation row or ESCALATED: entry)
type: regex
pattern: 'gocognit[^\n]{0,240}\bR3\b'
match: contains
target: trace
---
