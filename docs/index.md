---
okf_version: "0.2"
---
# Repo Map

- [conventions.md](conventions.md) — how to maintain this doc root (read before editing docs)
- [generator.md](generator.md) — how the Go plugin directory is generated from core/ and lang/go/, and the checks that keep it honest

**Behavioral evals of the Go plugin**
- [eval-harness.md](eval-harness.md) — what the behavioral evals are and how a run flows from case to verdict; `ldd-eval`, tiers, results
- [eval-fixture.md](eval-fixture.md) — the go-mini fixture and the violations manifest: plants, controls, scaffolds, and the checks that keep them honest
- [eval-cases-and-graders.md](eval-cases-and-graders.md) — how to write an eval case: prompt frontmatter, case.yaml, the five grader types, postcheck scripts, art judges, calibration rules
- [eval-runner.md](eval-runner.md) — how `ldd-eval` runs, regrades and resumes cases headlessly, and what to delete when `claude plugin eval` opens
- [eval-baseline.md](eval-baseline.md) — how a baseline is recorded and compared: noise floor, regrade, the acceptance procedure for a plugin refactor
