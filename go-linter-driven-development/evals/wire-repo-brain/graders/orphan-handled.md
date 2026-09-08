---
# the orphan doc is indexed (and/or reported stale/unwired) — either way the report names it
type: regex
pattern: 'heartbeat-protocol'
match: contains
target: last_message
---
