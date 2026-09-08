---
type: regex
pattern: 'R3 \| \S*device_service\.go:[0-9]+ \|.{0,700}(gocognit|cognitive|gocyclo|cyclomatic|funlen|nestif|\bQ1\b)'
flags: s
match: contains
target: last_message
---
