`git diff --cached -- '{{.SrcGlob}}'` filtered to added lines that carry the
language's comment marker (`//`, `#`, `/*`, `--`, a docstring opener), minus
directive lines — compiler pragmas, build tags, the linter's suppression
directive, doc-test output markers