---
okf_version: "0.2"
---
# Repo Map

- [conventions.md](conventions.md) — how to maintain this doc root (read before editing docs)
- [generator.md](generator.md) — how the plugin directories are generated from core/ and one binding under lang/, and the checks that keep them honest
- [language-residue.md](language-residue.md) — how Go idioms left in core prose are rendered per language binding — the five outcomes (rewrite, scalar, include, aside, override), the seam rules, the generic binding's instruction-with-examples shape, the Python binding's eight positions, the ts-react binding's nine, and the Claude Code names a second plugin must not collide on
- [handbook.md](handbook.md) — the coding-rules handbook — the standalone document a team reads without the plugin, how it is generated from the same rules, what a binding writes for it, and how to consume and measure it
- [mutation-tooling.md](mutation-tooling.md) — why the Go binding's R7 runs gremlins and not mewt — the four requirements the rule puts on a mutation tool, both tools measured on the same leaf packages, the blind spots the hand check covers, and the three changes in mewt that would reopen the decision

**Behavioral evals of the plugins**
- [eval-harness.md](eval-harness.md) — what the behavioral evals are and how a run flows from case to verdict; `ldd-eval`, tiers, results
- [eval-fixture.md](eval-fixture.md) — the go-mini, py-mini and ts-react-mini fixtures and their violations manifests: plants, controls, scaffolds, and the checks that keep them honest
- [eval-cases-and-graders.md](eval-cases-and-graders.md) — how to write an eval case: prompt frontmatter, case.yaml, the five grader types, the report contract graders lean on, postcheck scripts, art judges, calibration rules
- [eval-runner.md](eval-runner.md) — how `ldd-eval` runs, regrades and resumes cases headlessly, and what to delete when `claude plugin eval` opens
- [eval-baseline.md](eval-baseline.md) — how a baseline is recorded and compared: noise floor, regrade, the acceptance procedure for a plugin refactor
- [eval-return-experiments.md](eval-return-experiments.md) — is linter-driven development worth its tokens: the twelve experiments that would answer it, the three-layer scorecard every run is graded on, the ISO 25010 framing that survives scrutiny, and the order to run them in
- [token-budget.md](token-budget.md) — the token budget — where a plugin session's tokens go, measured on the Go baseline, the staged design that cuts the spend without changing what the rules say, and the two gates (verdicts and spend) every stage must pass to prove it
- [linter-authority.md](linter-authority.md) — the linter as the authority — the recommended lint setup per binding, the gap linter for the thresholds no linter holds, the Detect-script seam, the implementer digest, three review-precision fixes, and the pull requests that ship them in order, each with its scope, files, gate and dependencies
