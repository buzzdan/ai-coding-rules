**If arguments provided** (`$ARGUMENTS`):
- Use as file pattern (e.g., `./pkg/parser/*.go`, `./pkg/parser/`)
- Validate files exist with glob/ls

**Otherwise** (default behavior):
- Use git to find changed files:
  ```bash
  git diff --name-only --diff-filter=ACMR HEAD | grep '\.go$'
  ```
- If no git repository or no changes, analyze all `.go` files in the project (excluding vendor/, testdata/)
