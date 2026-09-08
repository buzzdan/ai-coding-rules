# evals — behavioral tests for go-linter-driven-development

The plugin's rules are data; these cases check that an agent running the plugin
actually does what the rules say, on a real (deliberately awful) Go project.
Cases are authored in the exact `claude plugin eval` file format so they survive
the day that command opens for this org; until then `runner/` (`ldd-eval`) runs
them over headless `claude -p`. Every run spends real money.

## Layout

| Path | What |
|---|---|
| `fixtures/go-mini/` | the fixture: a device-fleet service planted with every rule's violations and controls; no hints in the tree |
| `violations.yaml` | the manifest — every plant and control, anchored by file + regex, with what each mode must do about it |
| `check-manifest.sh` | keeps the manifest honest: anchors match, no hint words, every rule has plants and controls |
| `scaffold/default.sh` | copies the fixture into a fresh git repo (one commit); `red-lint.sh` also strips every `//nolint` |
| `<case>/` | `prompt.md` (frontmatter + prompt), `graders/*.md` (one grader per file), `case.yaml` (scaffold, postcheck, tier), `postcheck.sh` |
| `postcheck/` | `lib.sh` shared helpers; `golangci.orig.yaml` and `assertion-counts.txt` — the fixture's original state |
| `tools/gen-review-graders.sh` | generates review-full's recall/cluster/precision graders from the manifest |
| `runner/` | the stop-gap runner; delete it when `claude plugin eval` is available |
| `results/` | run output; gitignored except `baseline-<sha>/` |

## Cases and tiers

| Case | Tier | Prompt | Checks |
|---|---|---|---|
| `trigger-go` | cheap | "implement …" in go-mini | skill auto-triggers, announcement line, stops after pre-flight |
| `trigger-non-go` | cheap | same prompt in a Python repo | skill does NOT trigger |
| `review-full` | cheap | `/go-ldd-review` | per-plant recall, cluster blocks, control precision, evidence protocol, read-only |
| `quickfix-red-lint` | medium | `/go-ldd-quickfix` on red-lint | FIXED vs ESCALATED routing, no nolint, config untouched, assertions kept |
| `prepare-sms` | medium | `/go-ldd-prepare "add an SMS channel…"` | PREPARATION LOG, MULTIPLY/R11, skeptic, no feature code, tests green |
| `wire-repo-brain` | medium | `/wire-repo-brain` | index/conventions/AGENTS/gate installed, root wired, installed gate is the oracle |

Rough cost per run on sonnet-5: trigger ≈ $0.10–0.30, review ≈ $2–6, medium ≈ $3–10. Cheap-tier
cases run 3×; medium 1×. Expensive (Autopilot) is not yet authored.

## Running

```
export PATH=$PATH:/root/go/bin           # task, golangci-lint, ldd-eval
cd evals/runner && go build -o /root/go/bin/ldd-eval . && cd ..
ldd-eval run --tag cheap --runs 3 --model claude-sonnet-5 --max-cost-usd 25 .
ldd-eval run --case review-full --runs 1 --keep-temp --out results/try .
```

`--case` is a glob over case names; `--keep-temp` keeps the scaffold dirs (path in `result.json`).
Output: `<out>/<case>/run-<i>/{trace.jsonl,result.json,postcheck.txt}` and `aggregate-result.json`.
Exit 0 when every case meets `--threshold` (default 1.0), 1 otherwise, 2 when `--max-cost-usd` is hit.

## The manifest drives the graders

`violations.yaml` is the single source for three consumers: review-full's recall/precision graders
(generated — run `tools/gen-review-graders.sh` after any manifest edit; never hand-edit
`recall-*`/`cluster-*`/`precision-*`), the refactor cases' "gone" oracles, and the future Python
parity report. Controls carry `symbol:` (what a false positive would mention) and optionally
`mention_ok: true` (a correct report legitimately names it — no precision grader).

## Postcheck

Graders read the transcript and the tree; they do not run commands. Each medium case has a
`postcheck.sh` that runs in the kept scaffold after the agent finishes (`EVAL_DIR`, `EVAL_OUT`
set) and does the strongest checks: `task test`, byte-identity of `.golangci.yaml`, assertion
counts per `_test.go`, git-log ratchets, and — for wire-repo-brain — the installed
`scripts/check-repo-brain.sh` itself. Exit 0 passes; it counts as one grader named `postcheck`.

## plugin-eval parity

Frontmatter keys are exactly plugin-eval's (`name, tags, runs, max_turns, timeout_seconds,
allowed_tools, model, append_system_prompt`); grader types are `regex | tool_used | tool_order |
file_exists | llm`. Differences: `case.yaml` (scaffold, postcheck, tier) is ours; the `llm` judge is a
single haiku vote here (plugin-eval uses 2-of-3); `--ablation` is not implemented.

## Baseline

Run the full suite once on main with `--out results/baseline-<sha>`, commit that directory, and
record per-case pass rates in the PR. Thresholds are never 100 %: the baseline sets the noise
floor that later refactors of the plugin must stay within.

## Calibrating graders

Graders are calibrated against real traces, never by re-running agents:
`ldd-eval regrade --out results/<run> <evals>` re-applies the current graders
to recorded traces (see `runner/README.md`). The first baseline run showed the
merged review report cites findings as `` `file.go:12` | … (R1 Q1 …) ``, not in
the hunter-block shape `R1 | file:line |`; the anchor and evidence graders were
loosened to that shape and every review case gained a `rule-cited` grader.
