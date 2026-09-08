---
# recall: the report names at least one file of this plant by basename.
# ids: R2.Q1.alert-exported-fields
type: regex
pattern: '(alert\.go|alert_service\.go)'
match: contains
target: last_message
---
