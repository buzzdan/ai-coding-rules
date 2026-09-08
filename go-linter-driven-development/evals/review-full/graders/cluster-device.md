---
# cluster: ≥2 hunters converge on "Device"; the report must render a
# 🔗 CLUSTER entry naming it. members: R2.Q1.device-literal-in-service, R2.Q1.device-exported-fields, R2.Q2.validate-device-in-method, R12.Q4.setter
type: regex
pattern: 'CLUSTER.*Device'
match: contains
target: last_message
---
