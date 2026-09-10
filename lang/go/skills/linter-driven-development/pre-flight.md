1. **Verify Go project**: `go.mod` in root or parent directories.
2. **Discover commands** (README.md, CLAUDE.md, Makefile, Taskfile.yaml, in that
   order): test + lint commands. Fallbacks: `go test ./...`, `golangci-lint run --fix`.
