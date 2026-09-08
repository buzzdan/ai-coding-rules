---
# control CTRL.R7.split-tables: healthy code that must draw no finding; its symbol must not
# appear anywhere in the report (a mention IS the false positive).
type: regex
pattern: 'TestParse\w+_(Success|Error)'
match: not_contains
target: last_message
---
