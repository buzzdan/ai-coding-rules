1. **Read project files** in order of preference:
   - `CLAUDE.md` (project-specific instructions)
   - `README.md` (project documentation)
   - `Makefile` (look for `test:` and `lint:` targets)
   - `Taskfile.yaml` (look for `test:` and `lint:` tasks)
   - `.golangci.yaml` (linter configuration)

2. **Extract commands**:
   - **Test command**: `go test ./... -cover`, `make test`, `task test`
   - **Lint command (report-only)**: this command must NOT fix. Strip any `--fix`
     flag and run the linter in report mode: `golangci-lint run` (or the project's
     lint command with `--fix` removed).

3. **Fallback to defaults** if not found:
   - Test: `go test ./...`
   - Lint: `golangci-lint run` (no `--fix`)
