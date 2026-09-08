# ldd-eval — behavioral eval runner for go-linter-driven-development

Stop-gap runner for the cases under `evals/` while `claude plugin eval` is gated for this org.
Cases use plugin-eval's exact file format (`prompt.md` frontmatter + body, `graders/*.md`);
only `case.yaml` (`scaffold_script`, `postcheck`, `tier`) is ours. **When the gate opens, delete
`evals/runner/` and keep the cases** — nothing in them depends on this module.

## Usage

    cd evals/runner && go build -o /root/go/bin/ldd-eval .
    ldd-eval run [--case glob] [--tag t] [--runs N] [--model m] [--judge-model m] [--plugin-dir p] \
                 [--keep-temp] [--resume] [--out dir] [--max-cost-usd x] [--threshold r] <evals-dir>
Every run spends real money. Smoke first: `ldd-eval run --case 'trigger-*' --runs 1 --max-cost-usd 1 ..`

| Flag | Default | Meaning |
|---|---|---|
| `--case` | all | `path.Match` glob over case names |
| `--tag` | all | keep only cases carrying the tag (`cheap`, `medium`, `expensive`, ...) |
| `--runs` | case `runs` (3) | runs per case |
| `--model` | case `model`, else `claude-sonnet-5` | agent model; always pinned on the command line |
| `--judge-model` | `claude-haiku-4-5` | model for `llm` graders |
| `--plugin-dir` | parent of `<evals-dir>` | plugin root passed to `claude --plugin-dir` |
| `--keep-temp` | off | keep scaffold dirs; path recorded as `scaffold_dir` in result.json |
| `--resume` | off | with `--out`, reuse every run that already has a `result.json` and execute only the rest; a killed tier continues where it stopped, and reused cost still counts against `--max-cost-usd` |
| `--out` | `<evals-dir>/results/<timestamp>` | output directory |
| `--max-cost-usd` | unlimited | abort with exit 2 once agent + judge cost exceeds this |
| `--threshold` | 1.0 | per-case pass rate required for exit 0 |

Outputs: `<out>/<case>/run-<i>/{trace.jsonl,stderr.txt,scaffold.txt,result.json,postcheck.txt,judge-<grader>.txt}`
and `<out>/aggregate-result.json` (`schemaVersion "1"`, `suite`, `cases[]`, `aggregates{passRate, averageScore, totalCostUSD}`).
Exit codes: 0 every case ≥ threshold · 1 some case below · 2 budget exceeded (aggregate still written) · 3 usage/infrastructure.

## Semantics worth knowing

- `regex` with `target: files` counts matching **lines** across the scaffold tree (`.git` skipped); `last_message`/`trace` count matches.
- `tool_used`: `input_match` is a regex over the compact JSON tool input; `min: 0 max: 0` means "must not call".
- `tool_order`: the first `before` call must precede the first `after` call, and both must occur.
- `llm` judge is a **single vote** (plugin-eval uses 2-of-3): one `claude -p --model <judge> --tools ""` call whose reply
  must end with `VERDICT: PASS|FAIL`. Its cost is `judge_cost_usd` in result.json and counts against `--max-cost-usd`.
- `is_error` results get a failing synthetic `execution` grader; timeouts/incomplete traces set `error` and skip grading.
  The agent runs with `IS_SANDBOX=1` because `--permission-mode bypassPermissions` is refused for root without it.

## Regrading without re-running

`ldd-eval regrade --out <previous-run-dir> [--case glob] [--tag t] [--judge-model m] <evals-dir>`
re-applies the cases' *current* graders to the traces already recorded under
`--out`, rewrites each `result.json` (agent cost, turns, and model are carried
over; judge cost is whatever llm graders spend now) and recomputes
`aggregate-result.json`. Use it to calibrate graders against real traces
without paying for agents again. Graders that read the working tree
(`file_exists`, `postcheck`, `regex` with `target: files`) need the scaffold:
run with `--keep-temp` if you intend to regrade those, otherwise they fail
with a "needs the kept scaffold" detail.
