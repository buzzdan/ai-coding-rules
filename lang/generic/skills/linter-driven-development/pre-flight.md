1. **Detect the language** from the repository's marker files, and treat the row it
   implies as an example to confirm against the files present, not a table to trust:
   `go.mod` → Go (`*.go` sources, `_test.go` tests, `//` comments, `//nolint`);
   `pyproject.toml`, `setup.cfg` or `setup.py` → Python (`*.py`, `test_*.py`, `#`,
   `# noqa`); `package.json` → TypeScript or JavaScript (`*.ts`/`*.js`, `*.test.ts`,
   `//`, `eslint-disable`); `Cargo.toml` → Rust (`*.rs`, `#[cfg(test)]` modules, `//`,
   `#[allow(...)]`); `pom.xml` or `build.gradle` → Java or Kotlin (`*.java`/`*.kt`,
   `src/test/`, `//`, `@SuppressWarnings`); a `.csproj` → C# (`*.cs`, `*.Tests`
   projects, `//`, `#pragma warning disable`). Several markers → one language at a
   time, each with its own row. No marker and no source files → say so and stop;
   there is no code for the workflow to work on. Where a language-specific
   linter-driven-development plugin is installed for the detected language, hand
   over to it: its rows are knowledge, these are detection.
2. **Discover commands** (README.md, CLAUDE.md, Makefile, Taskfile.yaml, `package.json`
   scripts, the CI workflow, in that order): the test command and the lint command the
   repository already runs, plus the linter's configuration file (`.golangci.yaml`,
   `ruff.toml` or `[tool.ruff]`, `eslint.config.js`, `clippy.toml`). Report-only runs
   strip the fix flag; the fix loop adds it back. There are no fallbacks: a command the
   repository does not define is never invented and a linter it does not use is never
   brought along. No test command found → ask before continuing. No linter found → the
   lint phases are skipped and say so, the ship summary says so, and every review
   report carries a 🟠 New Practice finding ("no linter configured"); the review
   continues on the rules alone.