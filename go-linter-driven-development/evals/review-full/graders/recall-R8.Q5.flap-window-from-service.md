---
# recall: the report names at least one file of this plant by basename.
# ids: R8.Q5.flap-window-from-service
type: regex
pattern: '(device_service\.go|snapshot_service\.go)'
match: contains
target: last_message
---
