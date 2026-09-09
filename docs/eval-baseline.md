---
type: guide
description: how a baseline is recorded and compared: noise floor, regrade, the acceptance procedure for a plugin refactor
---
# Baselines and Comparison

## Recording one
Run the cheap tier two or three times per case and the medium tier once, with the
model pinned, `--keep-temp` on, and the output directory named for the commit of the
cases (`results/baseline-<sha>/`). Regrade once after calibration so every
`result.json` carries the current graders' verdict. Commit the directory: traces
compress well and are what makes later calibration free. Write a README beside it
with the per-case table, the findings, the noise floor and every grader change made
after the run.

The current baseline measures the plugin at `main` 681fdb0 and lives at
`evals/results/baseline-97194e3/`.

## The noise floor
Graders that flip between runs of the same case, on the same plugin, are the noise
floor. In the current baseline: two graders flip on Case C's review, five on Case
E's, twenty-three on the whole-repo review; every other case is stable. The
practical reading rules:

- A per-case change smaller than one flipping grader is noise.
- Compare the whole-repo review on its grader count (91 to 94 of 111), not on
  pass or fail.
- A single llm judge flipping between a live run and a regrade of the same file is
  noise until the judge votes two of three.

## Comparing after a refactor
This is the acceptance procedure for the language-neutral core extraction, whose
promise is that the generated plugin behaves the same as the hand-written one:

1. Run the cheap tier once and the medium tier once against the generated plugin,
   same model, same graders, into a new `results/` directory.
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
