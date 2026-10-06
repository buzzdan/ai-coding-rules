**MANDATORY** after creating new types or extracting functions, hooks or components:
1. List created types: `grep -rnE "^export (interface|type|class)[[:space:]]+\w+" --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`
2. Missing tests for any of them → STOP and invoke @testing. Before a move,
   characterization tests through the public API (`renderWithProviders` + MSW,
   never a `vi.mock` of the module being moved); `npx vitest run <dir>` after each step.
3. Coverage: `npx vitest run --coverage` (or the repository's coverage command) —
   leaf types must show 100% (R7).
