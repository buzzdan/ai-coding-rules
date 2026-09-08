---
# recall: the report names at least one file of this plant by basename.
# ids: R9.Q4.what-comments
type: regex
pattern: '(device\.go|heartbeat\.go|schedule\.go|device_service\.go|notify\.go|cache\.go|trace\.go|reporter\.go|env\.go)'
match: contains
target: last_message
---
