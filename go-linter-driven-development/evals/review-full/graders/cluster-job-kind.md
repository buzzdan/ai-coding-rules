---
# cluster: ≥2 hunters converge on "Job.Kind"; the report must render a
# 🔗 CLUSTER entry naming it. members: R11.Q1.job-kind-if
type: regex
pattern: 'CLUSTER.*Job\.Kind'
match: contains
target: last_message
---
