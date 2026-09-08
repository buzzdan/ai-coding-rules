---
# recall: the report names at least one file of this plant by basename.
# ids: R8.Q3.context-background-in-service
type: regex
pattern: '(device_service\.go|sync_service\.go|registry\.go)'
match: contains
target: last_message
---
