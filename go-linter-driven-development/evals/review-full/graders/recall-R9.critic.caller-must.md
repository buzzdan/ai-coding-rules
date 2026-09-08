---
# recall: the report names at least one file of this plant by basename.
# ids: R9.critic.caller-must, R2.Q4.caller-must-comments
type: regex
pattern: '(heartbeat\.go|device_service\.go)'
match: contains
target: last_message
---
