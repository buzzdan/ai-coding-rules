---
type: guide
description: how to write an eval case: prompt frontmatter, case.yaml, the five grader types, the report contract graders lean on, postcheck scripts, art judges, calibration rules
---
# Writing Cases and Graders

A case is a directory under `go/cases/` in the evals repository with three parts.
The file format is `claude plugin eval`'s, so a case needs no change when that
command becomes available; only `case.yaml` is ours.

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
Paths are relative to the case directory; the run task copies cases, scaffold,
postcheck helpers and fixture side by side below the plugin, so `../scaffold/` and
`../postcheck/` resolve there.

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
- **Lean on the report contract, nothing else.** The review skill promises that every
  finding's `file:line` anchor appears (heading its own line, or listed on a
  shared-shape line with the findings that share its evidence and fix), that the
  evidence names the rule and falsifying question by number, that the move is named
  as the rule's Fix pattern spells it, that findings are never rolled up into a
  count; and one
  `🔗 CLUSTER: <anchor>` entry per anchor that two rules converged on. That is what
  the recall graders (a plant's file basename anywhere), the question-id graders (the
  anchor, then `Q<n>` within 500 characters), the fix graders (the move's name) and
  the cluster graders (the word cluster and the anchor on one line, or a bullet under
  a clusters header) read. Anything a report is not promised to say — a banner, a
  count, a verdict's punctuation — is wording, and a grader on it will flip.
  The refactoring skill promises the same of its `Stop check` block: six lines
  opening `1 gates` … `6 commit`, in the message that ends the turn, whichever path
  invoked the skill (standalone, the workflow's ship summary, quickfix's), and under
  them one `BROADER CONTEXT` line per hit the detection re-run reported rather than
  fixed. The `stop-check` grader in every refactor case reads those six openings.

## Postcheck
Graders read the transcript and the tree; they do not run commands. A medium case
adds `postcheck.sh`, run in the kept scaffold after the agent finishes with the
directory in an environment variable, and it counts as one grader named
`postcheck`. `go/postcheck/lib.sh` provides the assertions: `task test` and
`task lint`, byte identity of the lint config, per-file test assertion counts with a
tree-total fallback when a test file was legitimately moved, complexity thresholds
on a named function, git-log ratchets (Case F requires at least three commits, a
non-increasing count of global reads, and no commit whose code changes reach beyond an
island and its caller — two packages — where a commit that changes only comments or
blank lines is not counted; every refactor case requires at least one commit
after the scaffold base and a clean tree at the end, because a green refactoring the
plugin leaves uncommitted has not shipped — and every refactor prompt asks for the
commit, because the harness commits only when the user asks), and the hidden black-box suite for the
centerpiece, which builds the service and replays recorded heartbeats.

## Art judges and the stop check
Every refactor case carries `graders/stop-check.md`, a regex over the final message
for the refactoring skill's six labelled `Stop check` lines in order: it fails when the
refactoring never rendered its exit, whether because a step was skipped or because the
ship summary narrated the steps in prose. It is the measurement that makes the
stopping criteria a contract rather than a checklist, the way the reconciliation header
did for the review report.

Every refactor case also carries `graders/art-judge.md`, an llm grader whose focus is the
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
