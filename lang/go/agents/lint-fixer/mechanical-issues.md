mechanical issues you fix —
formatting, import ordering, unused vars/params, unchecked errors (`errcheck`),
error wrapping (`wrapcheck`: `fmt.Errorf("context: %w", err)`), constant extraction
(`goconst` — mechanical ONLY when the repeated value is not an enum-shaped domain
concept; enum-shaped hits like `== "READY"` status strings escalate, see the table),
renames (`varnamelen`, `misspell`), simple style fixes (revive
`early-return`).
