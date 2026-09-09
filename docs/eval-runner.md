---
type: guide
description: how `ldd-eval` runs, regrades and resumes cases headlessly, and what to delete when `claude plugin eval` opens
---
# The Runner

`runner/` in the evals repository is a small Go module that builds `ldd-eval`. It exists because
`claude plugin eval`, the CLI's own command for this job, is early access and closed
for this organization. The cases do not depend on the runner; when the gate opens,
delete the directory and run the same cases with the CLI. The flag reference lives
in the module's own README; this page is the mechanism.

## What one run does
1. **Scaffold.** Run the case's scaffold script into a temp directory: a fresh git
   repo with the fixture and one base commit, so diff-based skills and git ratchets
   have a base.
2. **Execute.** Start `claude -p` in that directory with the plugin directory
   (`--plugin-dir`, required: a run always names the plugin it measures), the
   case's model, tool allowlist, turn and time limits, and the appended system
   prompt, in permission-bypass mode with stream-json output. Every event is written
   to `trace.jsonl` as it arrives.
3. **Grade.** Parse the trace, run each grader, run the postcheck if the case has
   one, and write `result.json` with the verdicts, cost, turns and model.
4. **Aggregate.** After all cases, write `aggregate-result.json` with per-case pass
   rates and total cost. Exit 0 when every case meets the threshold, 1 otherwise,
   2 when the cost cap tripped, 3 on a usage or infrastructure error.

    # in the evals repository
    task go:run TIER=cheap CAP=60 PLUGIN=/path/to/go-linter-driven-development
    # from this repository: clones the evals repository into .evals/ and runs the same task
    bash scripts/evals.sh TIER=cheap CAP=1 CASE='trigger-*'

The task builds the runner, copies the suite below the plugin, pins the model
(`MODEL`, default `claude-sonnet-5`) and sets the cost cap (`CAP`). Output lands in
`results/go-<timestamp>/<tier>/`, or under `OUT` when given. Always pin the model,
always set a cap, and smoke-test a new case with the trigger cases first: they cost
cents.

## Regrade
`task go:regrade OUT=<previous run> TIER=<tier>` re-applies the cases' current
graders to the traces already recorded under `<previous run>/<tier>` and rewrites
each `result.json`. Agent cost, turns and
duration are re-read from the trace; only the llm judges spend anything. This is how
graders are calibrated without paying for agents again. Graders that read the tree
(files, `file_exists`, postcheck) need the scaffold, so runs you intend to regrade
must use `--keep-temp`, which records the scaffold path in the result. A run still in
flight (trace present, no result yet) is skipped; a run that hit its turn cap keeps
its synthetic execution failure.

## Resume
The container running headless evals is reclaimed when the session goes idle, and a
detached run dies with it. `task go:run RESUME=1 OUT=<dir>` reuses every run
under the output directory that already has a `result.json`, counts its cost toward
the cap, and executes only the rest. The evals repository's manual CI workflow
uploads the results directory even when a run fails, for the same reason. Select the whole tier in one invocation when the
cap should be cumulative; with `--case` the ledger sees only that case.

## Segments
An agent that schedules its own wakeups makes headless Claude emit one result event
per segment, and the report can land in any of them. The trace parser sums turns and
duration across segments, keeps the final cumulative cost, records the count as
`segments` in the result, and defines the final message as every segment's final
text joined in order. Any value above 1 is the "waits badly" pathology the baseline
found, and is worth reading before trusting a cost figure.

## Parity with the gate
Same frontmatter keys, same five grader types, same output shape. Differences: the
llm judge is a single vote here where the gate uses two of three, so a single flip
between a live run and a regrade is noise; `--ablation` (the with-and-without arm
that measures the plugin's own value) is not implemented. Both are reasons to
switch the day the gate opens.
