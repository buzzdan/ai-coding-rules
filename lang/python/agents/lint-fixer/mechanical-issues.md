mechanical issues you fix —
formatting (`ruff format`), import ordering (`I`), unused imports/variables/arguments
(`F401`, `F841`, `ARG`), exception chaining (`B904`: `raise X(...) from err`),
narrowing a bare or broad `except` (`E722`, `BLE001`), magic values (`PLR2004` —
mechanical ONLY when the repeated value is not an enum-shaped domain concept;
enum-shaped hits like `== "READY"` status strings escalate, see the table), return
style (`RET`), simplifications (`SIM`), a positional boolean made keyword-only
(`FBT001`), ty `invalid-argument-type`/`invalid-assignment` mismatches fixed at the call or the
annotation (never with `# ty: ignore`).
