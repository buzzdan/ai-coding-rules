---
# recall: the report names at least one file of this plant by basename.
# ids: R1.Q3.region-byte-slices
type: regex
pattern: '(device_service\.go|heartbeat_parser\.go|tags\.go)'
match: contains
target: last_message
---
