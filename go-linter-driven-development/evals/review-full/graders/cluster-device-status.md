---
# cluster: ≥2 hunters converge on "Device.Status"; the report must render a
# 🔗 CLUSTER entry naming it. members: R1.Q3.status-string-compare, R1.Q3.status-enum-goconst, R11.Q1.status-switch
type: regex
pattern: 'CLUSTER.*Device\.Status'
match: contains
target: last_message
---
