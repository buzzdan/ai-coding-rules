---
# cluster: ≥2 hunters converge on "Alert.Channel"; the report must render a
# 🔗 CLUSTER entry naming it. members: R1.Q3.raw-channel-string, R2.Q1.alert-exported-fields, R11.Q1.channel-switch, R11.Q3.default-unknown-channel
type: regex
pattern: 'CLUSTER.*Alert\.Channel'
match: contains
target: last_message
---
