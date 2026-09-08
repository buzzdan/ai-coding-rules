# Baseline 97194e3 — cheap tier and a medium-tier subset

Plugin at `main` 681fdb0 (v2.10.0), cases and fixture at `97194e3` with graders calibrated
afterwards and re-applied by `ldd-eval regrade` (no agent re-spend). Agent model pinned to
`claude-sonnet-5`, judge `claude-haiku-4-5`, run 2026-09-08 from a headless container.

    ldd-eval run --tag cheap --model claude-sonnet-5 --max-cost-usd 60 --out results/baseline-97194e3/cheap <evals>
    ldd-eval run --resume … --max-cost-usd 80 …          # after the cap tripped at $65.97, for the six trigger runs
    ldd-eval regrade --tag cheap --out results/baseline-97194e3/cheap <evals>

Every run's `result.json` is the regraded verdict; `trace.jsonl` is the full stream so the
graders can be re-applied again. Total agent spend **$66.13**, judge $0.10.

## Pass rates

| Case | Passed | Turns | Cost | Reads as |
|---|---|---|---|---|
| trigger-non-go | 3/3 | 1,1,1 | $0.17 | negative trigger control holds |
| trigger-go | 0/3 | 1,1,2 | $0.20 | names the skill, never invokes it or announces (see caveat) |
| case-a-retention-review | 0/2 | 27,38 | $2.93 | skeptic REFUTES `RetentionDays` at score 1 |
| case-b-endpoint-review | 0/2 | 27,32 | $2.52 | skeptic REFUTES `Endpoint` parameter object and `Scheme` enum at score 1 |
| case-c-picker-review | 0/2 | 32,31 | $3.26 | skeptic REFUTES the leaf type; no falsifying-question ids cited |
| case-d-ceremony-review | 2/2 | 27,30 | $2.12 | negative control: no extraction proposed for earned ceremony |
| case-e-nils-review | 1/2 | 37,84 | $5.68 | run 2 missed the nil-return sentinel and produced no cluster block |
| case-f-globals-review | 2/2 | 48,123 | $7.37 | init(), both global reads, test mutation, clean-island fix all reported |
| centerpiece-storify-review | 2/2 | 46,46 | $9.73 | three clusters, critic verdicts on all 50 comments, skeptic CONFIRMS `Status` at 6 |
| review-full | 0/3 | 57,149,82 | $32.14 | 94, 92, 91 of 111 graders; whole-repo recall gaps differ per run |

Suite pass rate 0.43 (10 of 23 runs), average grader score 0.82.

## Findings about the plugin (Phase 2 targets, in order)

1. **The overabstraction skeptic refutes narrow, valid extractions.** Cases A, B and C
   propose one small type each (a validated int, a three-field parameter object, a leaf
   type); the skeptic scores every one 0–1 and the report demotes them to "dedupe into a
   helper". The same skeptic confirms `Status` at score 6 in the centerpiece, where the
   duplication spans eight sites. The rubric rewards breadth of duplication and never
   credits "makes invalid state unrepresentable".
2. **Whole-repo review recall is ~85 % and the misses move.** review-full passes 91–94 of
   111 graders each run, but 23 graders flip between runs: run 1 missed Case C and the
   R6/R7 test plants, runs 2 and 3 missed Case A and the R4/R5 package plants. Each run
   also clustered a different subset (ProcessHeartbeat in 1 of 3, Catalog.Find and
   Reporter in none). Run 2 raised a false positive on the R1 control (`Tenant` already
   has a type and a parser).
3. **Headless sessions wait badly.** Six of 23 runs spawned their hunters without the
   foreground flag, then polled `ReadNotifications` (up to 82 calls), armed `Monitor`
   loops, or scheduled wakeups that later fired as stale notifications. Turns and cost
   roughly doubled with no change in findings: case-e run 2 (84 turns, $4.00), case-f
   run 2 (123 turns over 12 segments, $5.05), review-full run 2 (149 turns over 16
   segments, $14.83). `segments` in each `result.json` records it; anything above 1 is
   this pathology.
4. **Reports drop the falsifying-question ids.** The skill's report example cites
   `(R1 Q1: yes; Q2: …)` per finding; two runs did, the rest cite only `R<n>`. The
   `r<n>-q<m>` graders in cases B, C and E measure this.
5. **The trigger does not fire headless.** All three trigger-go runs answered from context
   in one turn: they named `linter-driven-development` as the right skill but never called
   the Skill tool and never printed the announcement the skill mandates. Caveat: the
   dry-run system prompt says "stop as soon as you have announced the workflow", which may
   itself have discouraged the call. Re-run with a neutral dry-run instruction before
   treating 0/3 as the trigger rate.
6. Earlier in the session (see `../baseline-7a6b119/aborted-background-subagents`): with no
   non-interactive note, the agent ended its turn while background subagents were still
   running. Every case now carries that note.

Bonus: the Case B review found a real unplanted bug, `dial` wraps the socket in `tls.Client`
without calling `Handshake`, so `Ping` proves TCP reachability only.

## Noise floor

Graders that flip between runs of the same case: case-c 2, case-e 5, review-full 23; every
other case is stable across its runs. For the next comparison, treat a per-case change
smaller than one flipping grader as noise, and compare review-full on its grader count
(91–94 of 111), not on pass/fail.

## Grader calibration applied after the run

All shape-only: basename file anchors (`config\.go:[0-9]+`), question ids within 500 chars
of the anchor, cluster headers matched on the word "cluster" regardless of emoji, number or
case, `Critic:` or `comment-critic`, the command's "Commit Readiness Report" banner
alongside the skill's, the comma-ok fix spelled as `(Device, bool)`, and size/nesting
numbers as R3 Q1 linter evidence. One grader was removed: `cluster-status-r3` expected R3
in the Device.Status cluster, which `violations.yaml` never defined; both runs correctly
put R3 in the ProcessHeartbeat cluster.

## Medium tier — subset (`medium/`)

Run once each with `--keep-temp` (scaffolds kept so file, postcheck and art judges regrade),
same model pins, $12.07 total against a $40 cap.

    for c in quickfix-red-lint prepare-sms wire-repo-brain case-a-retention-refactor; do
      ldd-eval run --resume --keep-temp --case "$c" --model claude-sonnet-5 --max-cost-usd 40 --out results/baseline-97194e3/medium <evals>
    done

| Case | Passed | Turns | Cost | Reads as |
|---|---|---|---|---|
| quickfix-red-lint | 0/1 | 121 | $7.65 | hit the 120-turn cap with no final report; lint 0 issues, no nolint, config untouched, 26 design findings escalated with rule routes, but the fix pass dissolved `utils`/`common` and kept 169 of 173 test assertions |
| prepare-sms | 1/1 | 47 | $1.36 | PREPARATION LOG, MULTIPLY gate, R11 named, skeptic consulted, one prep commit (channel strings → constants), no feature code |
| wire-repo-brain | 1/1 | 33 | $0.93 | OKF bundle wired and the check script passes |
| case-a-retention-refactor | 1/1 | 62 | $2.13 | `Retention` type in its own file with `ParseRetention(raw) (Retention, error)` and `Expired(createdAt, now)`; `policy.go`/`config.go` deleted; `Prune` reads as a story; **art judge PASS** |

Findings added by this subset:

7. **The refactor path produces the art the review path refuses.** Given the Case A files
   and the plain instruction to fix them, the workflow extracted exactly the domain type
   the skeptic scored 1 in the review (finding 1), moved it into its own file, gave it
   the two methods the story needs, and left nothing behind. The art judge passed it
   with quotes for every criterion. The gap is in the review's skeptic, not in the
   refactoring skill.
8. **Quickfix has no stopping rule.** The lint-fixer classified correctly and reported
   `LINT STATUS: escalations pending (26)`; the parent then executed every escalation
   itself in one session, 41 edits and 9 new files, until the turn cap ended it without
   a report. The command's own text says escalations route through the refactoring
   skill design-first, so the behavior is in spec; the cost and the lost assertions are
   the finding. lint-fixer also wrote its escalations as a table, not the `ESCALATED:`
   lines its contract specifies.
9. **Nothing commits.** Neither the quickfix nor the Case A refactor made a commit; the
   working tree held the result. prepare-sms did commit, as its skill demands. The
   refactor cases' prompts ask for the workflow, whose SHIP phase ends in a commit.

Judge cost for the subset $0.05. The art judges were dry-checked on the untouched fixture
first: six FAIL, the Case D control PASSes (`README.md` of each case's `graders/art-judge.md`).

## Infrastructure notes

The container was reclaimed twice while the session idled, killing the detached run each
time (once at run 9, once at run 14). `ldd-eval run --resume` reuses finished runs, so only
the in-flight run was lost each time. The trace parser now folds a self-resuming session's
multiple result events (turns and duration summed, `last_message` spanning every segment).
