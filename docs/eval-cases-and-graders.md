---
type: guide
description: how to write an eval case: prompt frontmatter, case.yaml, the five grader types, postcheck scripts, art judges, calibration rules
---
# Writing Cases and Graders

A case is a directory under `evals/` with three parts. The file format is
`claude plugin eval`'s, so a case needs no change when that command becomes
available; only `case.yaml` is ours.

## prompt.md
YAML frontmatter, then the prompt the agent receives.

```markdown
---
name: case-a-retention-review
tags: [cheap, review, logic-hunter, case-a]
runs: 2
max_turns: 60
timeout_seconds: 1800
allowed_tools: [Bash, Read, Grep, Glob, Agent, Skill]
append_system_prompt: |
  You are running non-interactively: there is no next turn and no user to
  answer. Never end your turn while a subagent you spawned is still running;
  when you spawn agents, run them in the foreground and wait for every result.
  Do not schedule wakeups; finish the task and print your final report.
---
/go-ldd-review internal/snapshot/policy.go internal/snapshot/config.go
```

Keys: `name`, `tags` (the first tag is the tier), `runs`, `max_turns`,
`timeout_seconds`, `allowed_tools`, optional `model`, `append_system_prompt`. The
non-interactive paragraph is in every case for a reason: without it, the first
baseline run ended its turn while background subagents were still working.
Read-only cases omit the editing tools from `allowed_tools`, and a grader confirms
they were never called.

## case.yaml
Ours, not the gate's. It names the scaffold, an optional postcheck, and the tier.

```yaml
schema_version: "1.1"
context:
  scaffold_script: ../scaffold/red-lint.sh
postcheck: ./postcheck.sh
tier: medium
notes: |
  free text for the reader; never shown to the agent
```

## Graders
One small markdown file per assertion under `graders/`. Frontmatter carries the
type and its fields; the body is a rubric for llm graders and a comment otherwise.

| Type | Fields | Checks |
|---|---|---|
| `regex` | `pattern`, `flags` (Go regexp flags such as `s`), `match`, `target` | `match` is `contains`, `not_contains` or `count:N`. `target` is `last_message` (the agent's final text), `trace` (the whole transcript, including tool results) or `files` (matching lines across the scaffold tree). |
| `tool_used` | `tool`, optional `input_match` (regex over the tool's JSON input), `min`, `max` | counts calls of a tool; `min: 0` and `max: 0` means "must never call" |
| `tool_order` | `before: {tool, input_match}`, `after: {tool, input_match}` | the first `before` call precedes the first `after` call, and both occur |
| `file_exists` | `path` | a path exists in the scaffold after the run |
| `llm` | `criteria`, `focus` | a Haiku judge reads the focus and the body's rubric and answers PASS or FAIL; `focus` is `last_message`, `{source: file, path: …}`, or `{source: files, paths: […]}` where a path may be a directory standing for its non-test Go files |

Two shapes learned the hard way:

- **Name the plant's shape, not the agent's words.** A grader for a skeptic verdict
  that matches "CONFIRMED (score" followed by a digit of four or more survived every
  run. Graders that matched a literal report banner, a literal cluster prefix, or the
  words "Null Object" had to be loosened three times: reports write "Commit
  Readiness Report" where the skill's example says "CODE REVIEW REPORT", number
  their clusters, and spell the idiomatic name.
- **`target: trace` is polluted by what the agent read.** Skill text returned to the
  agent appears in the transcript, so a pattern like a rule id alone matches the
  plugin's own prose. Require the finding's specifics on the same line (the linter
  name with its rule route, a file anchor near the question id).

## Postcheck
Graders read the transcript and the tree; they do not run commands. A medium case
adds `postcheck.sh`, run in the kept scaffold after the agent finishes with the
directory in an environment variable, and it counts as one grader named
`postcheck`. `evals/postcheck/lib.sh` provides the assertions: `task test` and
`task lint`, byte identity of the lint config, per-file test assertion counts with a
tree-total fallback when a test file was legitimately moved, complexity thresholds
on a named function, git-log ratchets (Case F requires at least three commits and a
non-increasing count of global reads), and the hidden black-box suite for the
centerpiece, which builds the service and replays recorded heartbeats.

## Art judges
Every refactor case carries `graders/art-judge.md`, an llm grader whose focus is the
whole package (concepts move into new files, and a judge pinned to a filename cannot
see that). The rubric asks four things and demands a quoted line for each: one named
box per concept; method names in domain words, not mechanics; one abstraction level
per function; comments gone where the name now speaks. The control case's judge
inverts the question: it passes only when nothing was added. Every judge was
dry-checked against the untouched fixture before use: six fail, the control passes.

## Calibrating
Never re-run agents to fix a grader. Record traces once, edit the grader, and run
`ldd-eval regrade` (see [eval-runner.md](eval-runner.md)). Before loosening a grader
ask which of two things happened: the report carried the substance in a shape the
pattern did not anticipate (loosen), or the substance is missing (leave it failing;
that is a finding). Both kinds are recorded in the baseline write-up.
