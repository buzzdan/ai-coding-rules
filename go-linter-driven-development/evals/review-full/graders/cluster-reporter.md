---
# cluster: ≥2 hunters converge on "Reporter"; the report must render a
# 🔗 CLUSTER entry naming it. members: CASE-E.nil-field-rechecked, CASE-E.exported-nilable-fields, CASE-E.nil-parameters
type: regex
pattern: 'CLUSTER.*Reporter'
match: contains
target: last_message
---
