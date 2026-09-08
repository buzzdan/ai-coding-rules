---
type: regex
pattern: 'func Parse\w*Channel\('
target: files
---
The manifest's refactor oracle for R11.Q1.channel-switch (`present:
'func Parse\w*Channel\('`): the channel discriminator now has ONE decision point
— a parser at the boundary (`ParseChannel`, `ParseAlertChannel`, ...). Not
name-locked beyond the `Parse…Channel` shape the manifest itself commits to.
