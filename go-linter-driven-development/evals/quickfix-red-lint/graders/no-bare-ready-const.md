---
# goconst on "READY" is enum-shaped: a bare const is the wrong fix (route R1 "Name enum strings")
type: regex
pattern: 'const \w+ = "READY"'
match: count:0
target: files
---
