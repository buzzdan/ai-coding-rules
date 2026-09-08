---
# cluster: ≥2 hunters converge on "ProcessHeartbeat"; the report must render a
# 🔗 CLUSTER entry naming it. members: R3.Q1.process-heartbeat, R3.Q2.parse-beside-decision, R3.Q3.block-comments, R1.Q1.inline-id-check, R1.Q4.minus-one-sentinel, R1.Q5.five-results, R1.Q5.heartbeat-clump, R2.Q5.tags-nil-or-slice, R10.Q5.goto-sleep-backoff, R11.Q4.force-flag-in-body
type: regex
pattern: 'CLUSTER.*ProcessHeartbeat'
match: contains
target: last_message
---
