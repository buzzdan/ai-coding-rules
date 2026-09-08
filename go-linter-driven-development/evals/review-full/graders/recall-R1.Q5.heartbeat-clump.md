---
# recall: the report names at least one file of this plant by basename.
# ids: R1.Q5.heartbeat-clump
type: regex
pattern: '(device_service\.go|heartbeat\.go)'
match: contains
target: last_message
---
