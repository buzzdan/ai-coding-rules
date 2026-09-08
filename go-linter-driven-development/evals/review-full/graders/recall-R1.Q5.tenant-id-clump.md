---
# recall: the report names at least one file of this plant by basename.
# ids: R1.Q5.tenant-id-clump
type: regex
pattern: '(device_service\.go|store\.go|file_repo\.go|mem_store\.go)'
match: contains
target: last_message
---
