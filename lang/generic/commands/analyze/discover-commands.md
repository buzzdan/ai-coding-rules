1. **Detect the language** from the marker files at the repository root — `go.mod`,
   `pyproject.toml`/`setup.cfg`/`setup.py`, `package.json`, `Cargo.toml`,
   `pom.xml`/`build.gradle`, a `.csproj` — confirmed against the source files
   actually present. Several markers → one language at a time.

2. **Read project files** in order of preference:
   - `CLAUDE.md` (project-specific instructions)
   - `README.md` (project documentation)
   - `Makefile` (look for `test:` and `lint:` targets)
   - `Taskfile.yaml` (look for `test:` and `lint:` tasks)
   - `package.json` scripts, `pyproject.toml` tool sections, the CI workflow under
     `.github/workflows/`
   - the linter's own configuration file (`.golangci.yaml`, `ruff.toml` or
     `[tool.ruff]`, `eslint.config.js`, `clippy.toml`)

3. **Extract commands**:
   - **Test command**: the one the repository defines — `make test`, `task test`, an
     `npm test` script, `pytest`, `cargo test` as CI runs it
   - **Lint command (report-only)**: this command must NOT fix. Strip any fix flag
     (`--fix`, `--write`) and run the linter in report mode.

4. **No fallbacks.** A command the repository does not define is not invented. No test
   command → the tests gate reports "no test command found" and the analysis
   continues. No linter → the linter gate reports "no linter configured", the review
   carries it as a 🟠 New Practice finding, and the design review runs on the rules
   alone — never a linter this plugin brought along.