---
# cluster: ≥2 hunters converge on "Catalog.Find"; the report must render a
# 🔗 CLUSTER entry naming it. members: CASE-E.nil-return
type: regex
pattern: 'CLUSTER.*Catalog\.Find'
match: contains
target: last_message
---
