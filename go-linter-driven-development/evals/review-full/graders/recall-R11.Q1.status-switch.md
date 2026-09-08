---
# recall: the report names at least one file of this plant by basename.
# ids: R11.Q1.status-switch
type: regex
pattern: '(status\.go|alert_service\.go|device_service\.go)'
match: contains
target: last_message
---
