mechanical issues you fix —
formatting, import ordering, unused variables/parameters/imports, unchecked errors,
missing context on a wrapped error, constant extraction (mechanical ONLY when the
repeated value is not an enum-shaped domain concept; enum-shaped hits like `==
"READY"` status strings escalate, see the table), renames the linter asks for
(length, spelling), simple style fixes (early return, redundant else).