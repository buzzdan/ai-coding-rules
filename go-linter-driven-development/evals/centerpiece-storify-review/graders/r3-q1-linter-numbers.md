---
type: regex
pattern: '(device_service\.go:[0-9]+|ProcessHeartbeat).{0,700}(gocognit|cognitive|gocyclo|cyclomatic|funlen|nestif|nesting levels|\bLOC\b|\bQ1\b)'
flags: s
match: contains
target: last_message
---
