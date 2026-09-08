---
# the ceremony wrappers (ReplicaCount, Name, Formatter) must draw a REFUTED verdict
type: regex
pattern: 'REFUTED'
match: contains
target: last_message
---
