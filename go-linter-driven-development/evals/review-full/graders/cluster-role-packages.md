---
# cluster: ≥2 hunters converge on "role packages"; the report must render a
# 🔗 CLUSTER entry naming it. members: R4.Q3.role-named-packages
type: regex
pattern: 'CLUSTER[^\n]*(role packages|common\b[^\n]*utils|utils\b[^\n]*common)'
match: contains
target: last_message
---
