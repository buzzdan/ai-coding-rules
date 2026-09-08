---
# cluster: ≥2 hunters converge on "retention"; the report must render a
# 🔗 CLUSTER entry naming it. members: CASE-A.retention-range-twice, CASE-A.defensive-recheck, CASE-A.zero-sentinel
type: regex
pattern: 'CLUSTER.*retention'
match: contains
target: last_message
---
