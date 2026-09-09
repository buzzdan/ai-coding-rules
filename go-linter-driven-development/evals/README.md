# evals — behavioral tests for go-linter-driven-development

The plugin's rules are data; these cases check that an agent running the plugin
actually does what the rules say, on a real (deliberately awful) Go project.
Cases are authored in the exact `claude plugin eval` file format so they survive
the day that command opens for this org; until then `runner/` (`ldd-eval`) runs
them over headless `claude -p`. Every run spends real money.

The mechanism is documented at the repo root, starting from
[`docs/eval-harness.md`](../../docs/eval-harness.md): the fixture and its answer
key, how to write a case and its graders, how the runner executes, regrades and
resumes, and how a baseline is recorded and compared. `runner/README.md` is the
flag reference.

## Quick start

```
export PATH=$PATH:/root/go/bin           # task, golangci-lint, ldd-eval
cd evals/runner && go build -o /root/go/bin/ldd-eval . && cd ..
ldd-eval run --case 'trigger-*' --runs 1 --max-cost-usd 1 .        # smoke, cents
ldd-eval run --tag cheap --model claude-sonnet-5 --max-cost-usd 60 --keep-temp --out results/baseline-<sha>/cheap .
ldd-eval regrade --tag cheap --out results/baseline-<sha>/cheap .   # after any grader edit; free
bash check-manifest.sh                                              # after any fixture or manifest edit
```

Measured cost per run on sonnet-5 (baseline-97194e3): trigger ≈ $0.06, scoped
review ≈ $1–5, review-full ≈ $7–15, refactor ≈ $1–3, quickfix ≈ $8. Cheap-tier
cases run 2–3×; medium 1×; expensive (autopilot-sms) runs once and only on
explicit cost approval. The current baseline and its write-up live under
`results/baseline-97194e3/`.
