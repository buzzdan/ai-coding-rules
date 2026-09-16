---
type: guide
description: how a baseline is recorded and compared: noise floor, regrade, the acceptance procedure for a plugin refactor
---
# Baselines and Comparison

## Recording one
Run the cheap tier two or three times per case and the medium tier once, with the
model pinned and one `OUT` directory for both tiers (`task <lang>:run` keeps scaffolds
and writes each tier to `OUT/<tier>`). Regrade once after calibration so every
`result.json` carries the current graders' verdict. Then promote the run:
`task <lang>:baseline OUT=<run dir> PLUGIN=<plugin dir>` creates
`baselines/go-<plugin version>-<plugin sha>/` (or `baselines/python-…/` for the
Python suite) in the evals repository with the
verdicts, every trace in one `traces.tar.zst`, the plugin pin in `plugin.json`, and
a README stub with the per-case table pre-filled. Finish the README with the
findings, the noise floor and every grader change made after the run, and commit.
Traces compress well and are what makes later calibration free; the scaffolds are
not committed, so graders that read the tree cannot be regraded from a clone.

The Go suite's current baseline measures plugin 2.11.0 at c78b55f and lives in the evals
repository at
[`baselines/go-2.11.0-c78b55f/`](https://github.com/buzzdan/ldd-evals/tree/main/baselines/go-2.11.0-c78b55f);
its README compares it case by case with the earlier
[`baselines/go-2.10.0-5828c34/`](https://github.com/buzzdan/ldd-evals/tree/main/baselines/go-2.10.0-5828c34),
which is the worked example of the procedure below, and names the reading guide for
the next comparison: one grader on a scoped review is noise, up to three on the
refactor cases C, F and the centerpiece is inside their observed swing and needs a
second run, any change on a case that has never flipped is a signal. The first
Python baseline, once the Python plugin exists, adds the parity report to its
README: per rule, recall on py-mini against recall on go-mini under the Go plugin,
so the rules with a large gap are where the Python binding spends next.

## The noise floor
Graders that flip between runs of the same case, on the same plugin, are the noise
floor. In the current baseline: two graders flip on Case A's review, one each on
Cases B, C and F, three on Case E's and on the centerpiece's; in the medium tier,
run twice, one grader on Case D, the centerpiece and quickfix, three on Case E. The
whole-repo review is read on its grader count (90 of 111 against the earlier band of
91–94), because two of its three runs reviewed an empty scope. The practical reading
rules:

- A per-case change smaller than one flipping grader is noise.
- Compare the whole-repo review on its grader count (91 to 94 of 111), not on
  pass or fail.
- In baselines graded by a single-vote judge (every baseline up to go-2.10.0-5828c34)
  an llm judge flipping between a live run and a regrade of the same file is noise;
  the runner now votes two of three, so a flip in a later baseline is a finding.

## Comparing after a refactor
This is the acceptance procedure for the language-neutral core extraction, whose
promise is that the generated plugin behaves the same as the hand-written one:

1. Run the cheap tier once and the medium tier once against the generated plugin,
   same model, same graders, into a new run directory under `results/`.
2. Regrade both the baseline and the new run with the same graders if any grader
   changed in between.
3. Per case, compare pass counts and, for the whole-repo review, the grader count.
   No case may move by more than one flipping grader; art judges must pass on the
   same cases.
4. Anything outside that band is a real behavior change. With the plugin text
   byte-identical, the suspect is the generator, not the plugin.

## Comparing after a behavior change
Each deliberate fix to the plugin names the cases it should flip. Re-run only those
cases, at their baseline run counts, and read the delta. One fix per pull request,
so a flip has one cause and a regression elsewhere has one suspect.

## Cost
Cheap tier about $66 for 23 runs; medium tier about $23 for 10 runs; a whole-repo
review is the expensive cheap case at $7 to $15 per run. Sessions that spawn
subagents in the background and then poll roughly double their cost; the
`segments` field in each result marks them.
