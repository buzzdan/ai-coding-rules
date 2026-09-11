---
type: architecture
description: what the behavioral evals are and how a run flows from case to verdict; `ldd-eval`, tiers, results
---
# The Eval Harness

## Problem & Solution
**Problem**: the Go plugin is rules-as-data — markdown that steers an agent. Unit
tests cannot tell whether an agent running it reviews, refactors and ships the way
the rules say. Before the plugin's text is restructured (a language-neutral core
plus per-language bindings) and before its behavior is deliberately changed, there
has to be a measurement of what it does today.

**Solution**: the [buzzdan/ldd-evals](https://github.com/buzzdan/ldd-evals)
repository holds behavioral test cases in the `claude plugin eval` file format, one
suite per language under `<lang>/`. Each case gives a fresh copy of a deliberately
bad Go service to an agent that has the plugin installed, records everything the
agent does, and grades the transcript and the resulting tree. A baseline recorded
against a named plugin commit is the reference every later change is compared
against.

The evals repository depends on this one and never the reverse: it pins the plugin
commit each baseline measured, while this repository carries only a pointer README
under the plugin's `evals/` directory and `scripts/evals.sh`, which clones the evals
repository into an ignored `.evals/` directory and runs a tier against the current
checkout (`task evals:run`). Nothing a user installs contains a fixture, a runner or
a trace.

## One run, end to end

    case dir                scaffold                 agent under test               graders
    prompt.md          ──▶  default.sh copies   ──▶  claude -p --plugin-dir p  ──▶  regex on the report
    case.yaml               fixture/go-mini          prompt = the case text         regex on the files
    graders/*.md            into a fresh git         writes trace.jsonl:            tool_used / tool_order
                            repo, one commit         every tool call, text,         postcheck.sh in the tree
                                                     final message                  llm judge (Haiku)
                                                                                          │
                                                                                          ▼
                                  results/<run>/<tier>/<case>/run-N/{trace.jsonl, result.json, postcheck.txt}

The runner is the stand-in for `claude plugin eval`, which exists in the CLI but is
gated per organization; see [eval-runner.md](eval-runner.md). The fixture and its
answer key are described in [eval-fixture.md](eval-fixture.md); authoring a case is
in [eval-cases-and-graders.md](eval-cases-and-graders.md); recording and comparing
baselines is in [eval-baseline.md](eval-baseline.md).

## Layout

| Path (in `ldd-evals`) | What |
|---|---|
| `runner/` | `ldd-eval`, the stop-gap runner, language-neutral; deleted the day the gate opens |
| `go/fixture/go-mini/` | the fixture: a device-fleet service planted with every rule's violations and a control per rule; no hints in the tree |
| `go/violations.yaml` | the answer key: every plant and control, anchored by file + regex, with what each mode must do about it |
| `go/check-manifest.sh` | keeps the manifest honest: anchors match, no hint words, every rule has plants and controls |
| `go/gen-review-graders.sh` | generates the whole-repo review's recall, cluster and precision graders from the manifest |
| `go/scaffold/` | `default.sh` copies the fixture into a fresh git repo; `red-lint.sh` also strips every `//nolint` |
| `go/cases/<case>/` | `prompt.md`, `graders/*.md`, `case.yaml`, optional `postcheck.sh` |
| `go/postcheck/` | shared shell helpers, the fixture's original lint config and assertion counts, the hidden black-box suite |
| `baselines/<lang>-<plugin version>-<plugin sha>/` | committed reference runs: verdicts, one `traces.tar.zst`, the plugin pin, the write-up |
| `results/` | run output, ignored; a run is promoted to `baselines/` by hand |

At run time the `go:cases` task copies the cases, scaffold, postcheck helpers and
fixture side by side into this repository's `go-linter-driven-development/evals/`,
which is ignored here except for its README, because the gated `claude plugin eval`
expects cases below the plugin directory.

## Tiers
Tiers are tags in each case's frontmatter, selected with `--tag`.

| Tier | Agent may | Cases | Runs | Cost per run |
|---|---|---|---|---|
| cheap | read only, write a report | two trigger cases, the whole-repo review, six scoped reviews (Cases A–F), the centerpiece review | 2–3 | $0.06 (trigger) to $15 (whole-repo review) |
| medium | edit code | quickfix on the red-lint scaffold, prepare, wire-repo-brain, six refactors (A–F), the centerpiece refactor | 1 | $1–8 |
| expensive | run the whole workflow unattended | autopilot on an SMS-channel spec | 1 | $30 or more; runs only on explicit approval |

Cheap answers "does the plugin see the problems"; medium answers "does it fix them
without breaking anything, and does the result read as art"; expensive answers "does
the whole loop hold together".

## The logic-hunter cases
Cases A–F each isolate one kind of tangled logic and run in two modes. The review
mode asks whether the hunters and the skeptic name the concept; the refactor mode asks
whether the type actually appears with behavior preserved, and an llm "art judge"
reads the resulting package the way a reviewer glances at it.

| Case | Plant | Expected shape |
|---|---|---|
| A | a retention setting parsed and range-checked in two places, re-checked in a loop, with a zero sentinel | one validated type owning the parse and the rule |
| B | host, port and TLS handed through three functions; the scheme decided twice | an endpoint value that answers its own questions |
| C | a loop driven by two boolean flags with inline validity checks | a named collection with comma-ok queries; the orchestrator reads as named calls |
| D | control: a small earned type and a one-line helper | left alone; anything added is a failure |
| E | nil as "optional" field, "absent" return and "use the default" argument | comma-ok, a null object, a constructor that owns the defaults |
| F | a global config read from every layer | the value pushed up to the composition root one deployable commit at a time |

The centerpiece is the fixture's heartbeat handler: one working, fully specified function at
cognitive complexity 76 that plants seven rules at once; a hidden black-box suite
replays recorded heartbeats against the rebuilt binary so any refactor is judged on
preservation.

## Results so far
The current baseline measures plugin 2.10.0 at 5828c34, the first generated plugin
directory, and lives in the evals repository under
[`baselines/go-2.10.0-5828c34/`](https://github.com/buzzdan/ldd-evals/tree/main/baselines/go-2.10.0-5828c34)
with a write-up: cheap 7 of 23 runs pass, medium 5 of 10 (run twice for a noise floor),
art judges 2 of 7. It was recorded from a Claude Code on the web container so that the
earlier baseline on 681fdb0 and every later run share one environment; its findings
drive the plugin's next changes, and the comparison procedure is in
[eval-baseline.md](eval-baseline.md).
