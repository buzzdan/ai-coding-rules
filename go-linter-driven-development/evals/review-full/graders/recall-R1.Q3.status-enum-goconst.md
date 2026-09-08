---
# recall: the report names at least one file of this plant by basename.
# ids: R1.Q3.status-enum-goconst
type: regex
pattern: '(alert_service\.go|device_service\.go|status\.go)'
match: contains
target: last_message
---
