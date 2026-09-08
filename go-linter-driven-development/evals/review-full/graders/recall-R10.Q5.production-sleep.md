---
# recall: the report names at least one file of this plant by basename.
# ids: R10.Q5.production-sleep
type: regex
pattern: '(device_service\.go|retry\.go|sync_service\.go)'
match: contains
target: last_message
---
