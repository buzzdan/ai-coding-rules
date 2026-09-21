---
type: guide
description: is linter-driven development worth its tokens: the twelve experiments that would answer it, the three-layer scorecard every run is graded on, the ISO 25010 framing that survives scrutiny, and the order to run them in
generated: 2026-09-21
status: draft
---
# Return Experiments

Two questions, twelve experiments, one scorecard, one ranking. First, is the plugin
worth its tokens: eight experiments that add the arm every baseline has been
missing, the same task without the plugin or with only its rules. Second, is the
code it leaves behind worth anything to the next agent: four experiments on a clean
twin of the fixture. This page is the design; nothing here has run yet. The evals
themselves are described in [eval-harness.md](eval-harness.md), their graders in
[eval-cases-and-graders.md](eval-cases-and-graders.md), and the way a run is
recorded and compared in [eval-baseline.md](eval-baseline.md).

**What the current evals prove.** The Python plugin's review finds the design
problems planted in py-mini: 218 of 222 known plants on the last three
whole-repository runs, control citations down to style disagreements, and clearly
better than the same rules rendered without Python knowledge.

**What they do not prove.** Nothing measures the code the plugin produces, nothing
compares it with a plain prompt, and the fixture is dense with the twelve diseases
by design. A review-full run costs about $11 and 35 minutes; a scoped review $1.50
to $5. Whether that buys anything a plain prompt would not is the open question.

Every budget on this page assumes five runs per cell.

## Part one: is the plugin worth its tokens?

| Experiment | Question it answers | What grades it | Budget |
|---|---|---|---|
| 1 · No-plugin control | Does the review earn its cost against a plain prompt? | Existing recall graders and judge | ~$65 |
| 2 · Refactor tier A/B | Is the code it produces better, per dollar? | Refactor oracles: gone, present, lint, tests | ~$120 |
| 3 · Cheaper model + plugin | Does it replace a stronger model on the refactor tier? | Same oracles as experiment 2, model swapped in the control. Runs only if 2 says the refactor skill matters and 7 leaves the model gap open. | ~$120 |
| 4 · Token accounting | Which rules pay for themselves? | Per-agent usage in existing traces, ablation | $0 then ~$50 |
| 5 · Repositories not built for it | Does recall survive a real codebase? | Historical refactoring PRs as the oracle | ~$60 |
| 6 · Acceptance rate | What does it do to your day? | Your accept / dismiss / wrong marks | $0 |
| 7 · Writing features, rules × models | Does the machinery prevent problems, or does a strong model, plain or with a rules file, write clean code alone? | Hidden tests, then a review-full on the result counting new plants | ~$310 first four cells, ~$420 the grid |
| 8 · Rules without the machinery | Is it the rules or the plugin? And which model needs which? | Same graders, 3 rule deliveries × 3 models | ~$140 for the cells that can surprise |

### 1 · The no-plugin control on the existing suite
Run review-full and the six scoped cases on py-mini with plain Claude Code and a
one-line prompt, five runs each, same model: *review this repository for design
problems, cite file and line*. The recall graders match filenames and survive any
report format; the categories judge reads the report as text and does too. Cluster
and precision graders lean on the plugin's report shape and are dropped for this
arm. You get recall, false positives, cost and minutes side by side. If plain
Claude finds 190 of 222 plants for $4 a run, the plugin's 218 for $11 is a number
you can argue about. If plain finds 120, the argument is over.

Grades: 74 recall graders, the categories judge. Arms: plugin (already recorded)
against plain prompt ×5. Budget: about $65, one day.

### 2 · The refactor tier, the test that grades code
The medium tier's six refactor cases have oracles that grep the tree after the fix:
the disease is gone, the type exists, lint and tests are green. That grades code,
not a report, and it has never been run on Python. Run each case with the plugin
and with a plain *fix this* prompt that names the problem, five runs each. Score
four things per run: oracle pass, cost, turns, diff size. Worth the tokens is
oracle passes per dollar. Diff size is the tiebreaker: a fix that passes the
oracle and touches twice the lines is a different kind of expensive.

Grades: the refactor oracles, unchanged. Arms: plugin ×5 against plain prompt ×5,
six cases. Budget: about $60 per arm.

### 3 · A cheaper model with the plugin against a stronger one without
The most persuasive shape a return can take. Same design as experiment 2 with the
model swapped in the control arm: Sonnet with the plugin against Opus without it.
If Sonnet plus plugin matches or beats Opus on the refactor oracles, the plugin
pays for itself in model cost alone. Record the price per run in both arms with
the same care as the pass rate. The result is a single sentence: *the plugin is
worth X dollars of model per task*, positive or negative. Experiment 7's first four
cells ask the same substitution question for writing features, and experiment 8's
Opus cell asks it for the review; neither grades a refactor against its oracle, so
this stays a separate arm. It runs only after experiment 2 shows the refactor skill
beats a plain fix prompt and experiment 7 leaves the model gap open.

### 4 · Where the tokens go, then ablate
Every trace already carries per-message usage and every hunter, skeptic and critic
call. Sum by agent across the six review-full runs on hand and you have a cost per
rule for free. Then ablate: the generator renders a plugin with one rule removed,
and one five-run review-full cell measures the recall lost against the tokens
saved. A rule that costs 15 percent of a run and fires on two plants is a candidate
to fold into a cheaper neighbour. The twelve-rule structure has never been priced.

Budget: $0 for the accounting, about $50 per ablation.

### 5 · Repositories that were not built for the rules
py-mini and go-mini are dense with the twelve diseases on purpose. Take two or
three open-source Python and Go repositories with a public history of refactoring
pull requests, run the review on the commit just before those PRs, and count how
many of the refactors the review predicted. Precision is unknowable here, since
nobody planted the problems. Recall against what maintainers chose to fix is the
closest thing to a field test that does not involve shipping. Keep the
repositories public: no WEKA code leaves the approved connectors.

Data: 2 to 3 public repositories, 5 to 10 PRs each. Budget: about $60.

### 6 · Acceptance rate in your own work
For a month, every review the plugin produces on a real repository, mark each
finding accepted, dismissed, or wrong. Acceptance rate is precision in the wild.
The dismissed pile tells you which rules are noise on real code, which no fixture
can. Cheapest experiment on the list and the only one that measures what the
plugin does to your day rather than to a benchmark. Three columns in a text file
are enough.

### 7 · Writing features: the plugin against every model, plain and with a rules file
Experiment 8 asks whether the machinery matters for finding problems. This one
asks whether it matters for not creating them, and whether a strong model writes
clean code on its own, with nothing or with two hundred lines of rules. It puts
the plugin's design-first and TDD skills on trial, not its review, and nothing
else on the page measures that half of the plugin.

Same three features as experiment 9, since they land on the rules' seams: a new
status with its transitions, a fourth region, a notification channel. Hidden tests
decide correctness. Then one review-full on each result, with the plugin, counting
findings. That second number is the one that matters: a feature that passes its
tests and adds four new plants is exactly what the plugin claims to prevent.

**One spec per feature, fixed before any run.** Every arm gets the same spec text
and the same one-line prompt, *implement this spec*, so all cells start from the
same orientation and the only variable is the model and what rules it carries. The
spec is written in the fixture's own vocabulary and says what the feature does, not
how: the new status, which transitions reach it and leave it, what a heartbeat in
the fourth region does, what the notification channel receives and when, and the
acceptance criteria as observable behaviour. The hidden tests are derived from that
spec and nothing else. Two things stay out of it: any mention of the twelve rules,
enums, exhaustive matches or where the change should land, since that would hand
the plain arms the design the plugin is supposed to supply; and any file or
function names beyond the ones a user of the system would know, since locating the
seam is part of the task. The specs are committed to the evals repository
alongside the cases and reused verbatim by experiment 9.

| Arm | Sonnet 5 | Opus 5 | Fable 5.1 |
|---|---|---|---|
| No rules (control) | first, the plugin cell's anchor | later | first, the model-upgrade reading |
| Coding-rules file | second, if a Fable cell is clean | later | first, the cell that decides it |
| Full plugin | first, the baseline | skip | skip |

Seven cells in the full grid, three features, five runs each. The plain row is the
baseline each rules-file cell is read against: without it a clean Fable result
cannot be credited to the file or to the model. The plugin column on the stronger
models is the same skip as in experiment 8: the skills are a scaffold, and the
graders cap what a stronger model inside them can show. The rules file is the same
one experiment 8 uses, written from the rule texts alone, by a person.

**Start with four cells, not seven.** Fable plain, Fable with the rules file,
Sonnet with the plugin, and Sonnet plain. The two Fable cells put the strongest
model against the plugin directly. Sonnet plain is the cheapest cell on the grid
and it anchors the plugin cell: without it a clean Sonnet-with-plugin result proves
nothing, since Sonnet alone might have written the feature clean.

| Cell | Runs | Estimate |
|---|---|---|
| Fable plain | 15 | ~$125 |
| Fable with rules file | 15 | ~$125 |
| Sonnet with plugin | 15 | ~$35 |
| Sonnet plain | 15 | ~$25 |
| First round | 60 | ~$310 |

| If | Then it means | Next cell |
|---|---|---|
| Fable plain reviews as clean as Sonnet with plugin | the plugin is competing with a model upgrade; only price is left to argue | Sonnet with rules file, ~$30 |
| Fable plain dirty, Fable with rules clean | the rules matter on the strongest model; only the ceremony is on trial | Sonnet with rules file, ~$30 |
| Fable with rules dirty, Sonnet with plugin clean | the design-first ceremony earns its cost even on the strongest model | none needed; the Opus column can wait indefinitely |
| Sonnet plain as clean as Sonnet with plugin | the plugin cell shows nothing on these features; they are too easy or the review too coarse | harder features before any new cell |

Clean and dirty mean the scorecard below: the hidden tests first, then the
structural deltas in ISO 25010 terms, then the plant count and the pairwise judge.
A feature that fails its tests is not clean whatever it reviews as, and a feature
whose plant count is low but whose structural deltas are bad is the plugin passing
its own exam and failing the independent one. Five runs per cell is the floor the
literature uses. If the two Fable cells land within a plant or two of each other
after five runs, spend on five more of each before spending on any new cell.

### 8 · The rules without the machinery, across models
The plugin is two things: twelve rules, and the machinery that applies them
(hunter fan-out, skeptic, comment critic, the report shape). This design pulls them
apart. Condense the twelve rules into one plain coding-rules file, the length of a
CLAUDE.md: rule name, falsifying questions as one line each, the fix names. Then
run the same review task three ways, none, summary file, full plugin, on three
models.

| Arm | Sonnet 5 | Opus 5 | Fable 5.1 |
|---|---|---|---|
| No rules (control) | ~$3 / run | ~$8 | ~$15 |
| Summary file | ~$4 | ~$10 | ~$20 |
| Full plugin | $11 (measured) | ~$28 | ~$55 |

Costs are review-full per run, scaled from the measured Sonnet runs by list price;
the Opus and Fable figures are estimates until one run pins them. Five runs per
cell. The graders are the same recall set and judge as experiment 1; the
summary-file arm may also take the precision graders.

Four readings fall out of the grid. Down a column: how much the machinery adds
over the rules alone on one model. Across a row: whether a stronger model closes
the gap that the machinery closes for Sonnet. The no-rules row is experiment 1's
control. And the cheapest cell that matches the plugin's Sonnet recall is the price
of the review in model terms; experiment 3 asks the same of the refactor skill,
against its oracles.

Two cautions. Write the summary file from the rule texts alone, not from the
fixture or the graders, or it will be a cheat sheet. And hold the report format
loose in the two lighter arms: the recall graders match filenames and the judge
reads prose, so a plain finding list scores fairly.

**Which cells can surprise.** Not the plugin column. The machinery is a scaffold,
and Sonnet already sits at 106 of 110; Opus with the plugin at 107 says nothing
worth $28 a run. The lighter rows are where a stronger model attacks the question
from the other side. If Opus with the summary file reaches what Sonnet reaches
with the plugin, the plugin is Opus-level review at Sonnet prices and its future is
tied to the price gap between models. If Opus with no rules finds 200 plants, the
twelve rules are mostly what a strong model already knows. So run the plugin
column on Sonnet only, the lighter rows on Sonnet first, then the summary file on
Opus as the one cell that could rewrite the plan. Skip Fable unless Opus lands
within a few plants of the plugin.

Budget: about $90 for the Sonnet row, about $50 for the Opus cell, about $770 for
the whole grid.

## Part two: does clean code pay off for the next agent?

The plugin rests on a bet: code that follows the twelve rules is cheaper for an
agent to read, change and extend than code that does not. Nothing has measured
that. The plugin is out of the picture in every experiment below on purpose. What
is measured is the code it leaves behind, and a plain agent's cost of working in it.

**The twin fixture.** py-mini is the dirty codebase. Build py-mini-clean: the same
behaviour with every plant fixed, by running the refactor tier across the six cases
and finishing by hand until review-full finds nothing planted. The same tests pass
on both, so any task has the same oracle on both twins. Every experiment is then
*same agent, same task, same model, both twins, five runs each*. Building the clean
twin is the real cost: about a day and $60 in refactor runs. The fixture itself is
described in [eval-fixture.md](eval-fixture.md).

What every run records, from the trace and the tree after the change:

| Metric | How | Answers |
|---|---|---|
| Tokens read | bytes returned by Read and Grep calls in the trace | is clean code cheaper to understand |
| Files opened | distinct paths in Read calls | does the story localize the change |
| Cost and turns | already in `result.json` | the price of the task |
| Oracle pass | hidden tests for the task | did it get it right |
| Regressions | existing tests broken after the change | did it break something else |
| Diff size | lines touched | did the change land where it belongs |

### 9 · Add a feature, with hidden tests
Tasks that land on the seams the rules are about: add a maintenance status and its
transitions, add a fourth region, add a notification channel. In the dirty twin
each of these touches the duplicated switches R11 names; in the clean twin it
touches one exhaustive match and one enum. The specs are experiment 7's, verbatim,
so both twins and every arm of 7 implement the same document. Hidden tests decide
the oracle; the existing suite decides regressions. If clean code is easier to
extend, this is where it shows first: fewer files opened, a smaller diff, no
regressions, less cost.

Arms: 3 to 4 features × 2 twins × 5 runs. Budget: about $80.

### 10 · Fix an injected bug, with a failing test
Inject the same bug at the same behavioural point in both twins, hand the agent
the failing test, and measure tokens to locate it and whether the fix is local. A
bug in a storified function should be found by reading the story and descending
into one helper; in the monolith it means reading the body. Choose bugs that live
in the plants' territory: a wrong transition, a region code accepted that should
not be, a retry that gives up one attempt early. The interesting number is tokens
read before the first edit.

Arms: 3 bugs × 2 twins × 5 runs. Budget: about $60.

### 11 · Answer a comprehension question
The storified-code question in its purest form. *What happens to a heartbeat whose
region tag is unknown? Which thread writes the last-seen field? What does the
scheduler do when the queue is empty at boot?* Each has a reference answer; grade
with a regex on the key facts plus a judge. Measure tokens consumed before the
answer arrives. Two cautions. Storified code may have more tokens in total, since
it has more names and signatures; the saving, if it exists, is in what the agent
does not read, so measure what is read, not file size. And agents often read whole
files regardless of structure, so the effect may be small on py-mini's file sizes.
Grep-ability is part of the answer: a named parsing helper is found by one Grep,
an inline block is not.

Arms: 8 questions × 2 twins × 5 runs. Budget: about $40, these runs are short.

### 12 · Five features in sequence, and what decays
The one that answers "long term". Apply five features one after another to each
twin, each run starting from the previous run's result, no plugin. Plot cost per
feature and regressions per feature across the sequence. Dirty code should decay
under AI maintenance: each change costs more than the last and breaks more. If the
clean twin's curve is flat and the dirty one's climbs, that is the payoff in one
chart. Run review-full on both end states and count findings: clean code should
stay clean under a plain agent longer than dirty code stays merely dirty.

Arms: 5 features × 2 twins × 5 sequences. Budget: about $250.

**What would convince.** Comprehension tokens down by a third and regressions down
by half on the clean twin would say the rules pay for themselves within a few
maintenance cycles. Equal tokens and equal regressions would say the plugin is a
review tool, not an investment, and its cost has to be justified per review, which
is part one's question.

## How to measure: the scorecard every run is graded on

Every experiment above grades code that an agent wrote or changed. Today the grade
comes from two places: the plugin's own review counting plants, and a Haiku judge
answering PASS or FAIL against a rubric. Both are the plugin measuring itself with
its own ruler. A reader outside the project will ask for a yardstick that does not
belong to the plugin. What follows is from a survey of the standards and of the
2023 to 2026 literature on grading agent-written code; the sources are listed at
the end.

**The ISO answer.** ISO/IEC 25010 is a vocabulary, not an instrument. It names
maintainability's five sub-characteristics (modularity, reusability,
analysability, modifiability, testability) and its companion ISO/IEC 25023 gives
abstract ratio formulas, of which only two are computable from source. ISO/IEC
5055, the CISQ automated measures, is concrete but has no open-source
implementation and its detection patterns are prose, so two tools do not count the
same. Any "ISO 25010 score" is a vendor's own metrics under ISO's names.

**The operationalisation worth adopting** is the Software Improvement Group's
maintainability model: TÜViT-certified, mapped explicitly onto the 25010
sub-characteristics, with published thresholds, and reimplementable with the
complexity tools the postcheck already runs plus a few additions named below. It
reports *risk profiles*, the share of code in the high-risk bands, never averages.

| 25010 sub-characteristic | SIG property and bands | Tools the postcheck runs today | Tools to add |
|---|---|---|---|
| Analysability | unit size: lines per function, bands 15 / 30 / 60; duplication: blocks of 6+ lines | radon (raw counts) | lizard or funlen for Go unit size; jscpd with one config for both languages |
| Modifiability | unit complexity: McCabe per function, bands 5 / 10 / 25; duplication; module coupling | radon cc, complexipy / gocyclo, gocognit | jscpd; the import-graph script below |
| Testability | unit complexity, unit size, component independence | as above; test placement read from the tree, as the postcheck already does | none beyond the above |
| Modularity | module coupling: fan-in; component balance; component independence; cyclic dependencies | none | an import-graph script over pydeps output and go list -deps, with a cycle count |
| Reusability | unit size; unit interfacing: parameter count | ruff and golangci-lint argument-count limits | lizard for parameter counts per function |

Rules visible to structural metrics: R3, R4, R5, R7, R8 and R11. Size, complexity,
coupling and duplication cover R3, R4, R5, R8 and R11; R7 is test placement, which
the tree shows directly and the postcheck already reads. The other six, R1, R2, R6,
R9, R10 and R12, are about types, test seams, documentation, concurrency and
encapsulated state, and no structural metric sees them. Only the review or a judge can. That boundary belongs
in every write-up: it is exactly what an international standard can and cannot say
about this plugin.

**Avoid, on the evidence.** The Maintainability Index in any tool: fitted on a
handful of 1990s C and Pascal systems, it penalises extract-method refactoring,
which is the plugin's main move. SonarQube's A to E letter and debt minutes:
remediation times are guesses and the grade depends on which rules are active.
TIOBE's TQI: proprietary, unvalidated weights. Cyclomatic or cognitive complexity
on their own: modest predictors, largely collinear with size. Normalising anything
by lines of code when arms write different amounts: volume added is itself one of
the strongest predictors of structural decay.

**Best evidence for predicting maintenance effort:** function size, and composite
smell scores such as CodeScene's Code Health, where low-health files took about
twice as long to change and carried many times the defects. Coupling and nesting
next. Process metrics such as churn beat all product metrics for defect
prediction, which is why part two's downstream-task measures matter more than any
static number.

### The three layers, per run

| Layer | Measures | Why this | Have / add |
|---|---|---|---|
| A · Correctness | hidden tests pass; existing suite regressions; a differential check of behaviour against a reference implementation; pass^k across the k runs of a cell, not pass@1 | around 30 percent of "plausible" agent patches on public benchmarks behave differently from the reference under differential testing; a single run correlates weakly with true reliability | have tests and postcheck; add the differential check and pass^k |
| B · Structure, as ISO 25010 via SIG | deltas against the pre-change tree: share of LOC in units over 30 and over 60 lines; share in units with McCabe over 10 and over 25; *erosion*, new complexity landing in functions already over the band; duplicated blocks; module fan-in and cycle count; unused code and hard-coded literals; volume added, reported raw | correctness-independent and owned by nobody in the project; erosion and verbosity rose in 80 and 90 percent of agent trajectories in one 2026 benchmark even when tests passed | have radon, complexipy, gocyclo, gocognit; add lizard or funlen, jscpd, the import-graph script and a pre/post diff script, none of which exists yet |
| C · Design | the plugin review's plant count, kept and labelled *rules conformance*; plus an independent judge: pairwise between two arms' diffs, position randomised and swapped, provenance blinded, comments and model names stripped, repo-grounded rubric, calibrated on about 30 pairs labelled by hand and reported with chance-corrected kappa | the plugin review is the plugin grading its own homework; absolute-scale PASS/FAIL judging is the weakest judge design in the literature, pairwise with position swaps holds up; superficial cues alone move judge accuracy by up to 27 points | have the review and the art judge; convert the art judge to pairwise |
| Always alongside | cost per passing feature; tokens in and out; turns; diff size | quality without price is not a return | have, in `result.json` |

### Method rules the literature agrees on

| Rule | Reason | What it changes here |
|---|---|---|
| Five independent runs per cell, not three | the common floor in agent evaluation; three cannot separate two arms a plant apart | every budget on this page assumes five |
| Paired tests across features, with a bootstrap interval | features differ more than arms do; pair by feature and use McNemar or a permutation test, cluster-robust by feature | the baseline compare reports means; add the paired test |
| Learn the noise floor first | a no-change baseline run twice tells you how far two identical arms drift | the noise floor in [eval-baseline.md](eval-baseline.md) covers the review; do the same for the scorecard |
| Pin the harness | holding a model fixed across 35 CLI releases moved quality by tens of points from harness changes alone | one Claude Code version for every arm of a round, recorded in the run |
| Report structure as deltas and distributions, pre-registered | SIG stars and Sonar grades are relative to moving populations; the raw bands and thresholds are what a reader can check | write the thresholds into the case before the first run |
| Write the rules file by hand | human-written instruction files added about 2.4 percent to success in one study; generated ones slightly hurt and raised cost by a fifth | experiment 8's summary file and experiment 7's rules file: from the rule texts, by a person |
| Expect small, fading rule-file effects | a 1,650-session factorial found file size, position and nesting had no detectable effect; the only real effect was decay within a session | a rules-file arm that reviews clean on a short feature and dirty on a long one is the expected shape, not noise |
| Measure the downstream task, not only the artefact | the best-validated maintainability measure for agent code is whether the next task on top of it succeeds | part two is the load-bearing evidence; a clean-versus-dirty minimal-pair study found pass rate flat, tokens down 7 to 8 percent, file revisits down 34 percent, which is the effect size to expect from 9 and 11 |

### Jev as the layer C scorer
TypeSafe's Jev, in waitlisted early access since 15 September 2026, answers typed
questions about a supplied state: a choice, a score or a boolean, each with a
calibrated probability, no text, in under half a second at $0.042 per million
input tokens. State plus the longest question must fit in 32k tokens. Layer C's
pairwise judge is a set of exactly such questions, so Jev is a candidate for its
scoring half. It is not a candidate for layers A or B, where tests and static tools
are already deterministic and free.

| Property | What is published | What it means here |
|---|---|---|
| Repeatability | variance on repeated scoring 92 to 913 times lower than GPT, Claude and Luna judges in LangChain's test | the Haiku judge's weakest property, gone; both position orders on every pair become affordable |
| Cost | one LangSmith evaluation run at $0.34 against $28 for Claude | every pair, every rule, every run, both orders |
| Accuracy | matched human pass/fail on a corpus of five agent runs and one reviewer; TypeSafe's own evals use labels averaged from two other frontier models | unproven on design judgments; the 30 hand-labelled pairs decide, reported as kappa |
| Reasoning depth | TypeSafe's limitations page names counting, arithmetic, multi-step indirection and noisy state | surface-shaped rules should work (R1, R8, R11); rules that follow code across functions (R3, R10, R12) are the expected misses |
| Evidence | returns a probability, never a rationale | the art judge's quoted line per criterion cannot come from Jev; keep an LLM for the quote on contested pairs |
| Adversarial state | documented susceptibility to instructions inside the supplied material | strip comments and docstrings before judging |
| Question shape | one write-up found single overall verdicts had 25 times the false positives of per-dimension scores | one question per rule per pair, never one verdict per pair |

**How to use it, if at all.** Gate on calibration: run the 30 hand-labelled pairs
through Jev and through the existing Haiku judge, both orders, and keep Jev only if
its kappa against the labels is at least Haiku's. Then, per pair of diffs for the
same feature and run index: state is the spec plus both diffs with comments
stripped, limited to the touched files so it fits 32k; questions are one Choice
per rule (A, B or tie) and one boolean per rule per diff; run both orders and keep
the probability, not the argmax. Route pairs with a probability near one half, or
in disagreement with the layer B deltas, to an LLM for a quoted line.

**Two constraints outside the technical ones.** Jev is not on WEKA's approved
connector list, so nothing from a WEKA repository is sent to it; that excludes
experiment 6. py-mini and go-mini are public fixtures in a public repository and
may go, with an explicit go-ahead first. And early access is a waitlist, so it
cannot be on the critical path: the plan works with the Haiku judge alone and Jev
is an upgrade to try, not a dependency.

**What this changes in the plan.** Layer B is new work before the first paid run:
a pre/post script over the tree that emits the SIG bands, erosion, duplication,
fan-in and volume, run in every arm of every experiment that changes code (2, 7,
9, 10, 12). Layer C's pairwise judge replaces the art judge's PASS/FAIL, with Jev
as its scorer if it passes calibration. Layer A's differential check needs a
reference implementation of each of the three features, which the specs already
imply. None of it is expensive; all of it is what makes a result quotable outside
the project.

## The ranking: decisions changed per dollar

Budgets are the cells that can surprise, not the full grids. Two of the top three
are free. The paid work concentrates in four experiments that each answer a
different question: 8's Sonnet row, 7's first four cells, 11 and 2, about $560
together.

| # | Experiment | Cost | What it can change | Why here |
|---|---|---|---|---|
| 1 | 6 · Acceptance rate | $0 | which rules stay in the plugin | free, measures real code, only accrues with time |
| 2 | 4 · Token accounting | $0 | where the next token cut goes | free from existing traces; makes every other result interpretable |
| 3 | 8 · Sonnet row | $90 | whether the plugin is rules or machinery | fifteen runs answer the question the design rests on, and contain experiment 1 |
| 4 | 7 · Writing features, first four cells | $310 | whether the implementation skills are worth their ceremony | the only test of the half of the plugin that writes code |
| 5 | 11 · Comprehension | $40 + twin | whether storified code is cheaper to read | cheapest test of the rules' own claim about agents |
| 6 | 2 · Refactor A/B | $120 | whether to keep building the plugin at all | most convincing to outsiders; grades code without interpreting prose |
| 7 | 8 · Opus summary cell | $50 | whether the plugin is priced against the model gap | one cell, one clear reading |
| 8 | 9 · Add a feature | $80 + twin | whether clean code is cheaper to extend | direct and well-oracled, but the clean twin costs a day first |
| 9 | 12 · Five in sequence | $250 | the long-term claim | the one chart that would sell the rules, the widest error bars; only after 9 shows a gap |
| 10 | 10 · Injected bug | $60 | whether bugs localize in clean code | overlaps 9 and 11 |
| 11 | 5 · Real repositories | $60 | generalization | soft evidence; only once 2 and 8 say there is something to generalize |
| 12 | 3 · Cheaper model + plugin | $120 | whether the refactor skill is worth a model tier | the refactor-tier substitution question; only after 2 says the skill matters and 7 leaves the model gap open |
| 13 | 8 · Fable column, plugin column on Opus | $500+ | nothing the cheaper cells do not show | the scaffold caps what a stronger model can add |

## What to run first

1. **The scorecard's structure script**, before any paid run: a pre/post pass over
   the tree emitting the SIG bands, erosion, duplication, fan-in and volume, plus
   the pairwise judge in place of the art judge's PASS/FAIL. A day of work, no
   model cost, and the thing that makes every result below quotable.
2. **Experiment 8's Sonnet row**, about $90. It contains experiment 1 and adds the
   arm that tells rules from machinery. Fifteen review-full runs, one day.
3. **Experiment 7's first four cells**, about $310: Fable plain, Fable with the
   rules file, Sonnet with the plugin, Sonnet plain, all implementing the same
   three specs. Then Sonnet with the rules file, about $30, if either Fable cell
   reviews clean. The Opus column waits.
4. **Experiment 2 on py-mini**, about $120, once the Sonnet row says the review is
   worth measuring further.
5. **Experiment 4's accounting** alongside. It costs nothing and says where to cut
   if either answer is thin.
6. **Experiment 6 starting now**, because it only accrues with time.

Then one Opus cell of experiment 8, the summary file, about $50. Fable only if
Opus lands within a few plants of the plugin. Hold 5 until then. Part two starts
with building py-mini-clean, since every experiment there needs it; then 11, then
9, then 12 if 9 shows a gap.

## Sources

Figures in the measurement section were read from abstracts and search snippets;
verify a number against the paper before quoting it externally.

**Standards.** ISO/IEC 25010:2023 and the changes from 2011, summarised at
[arc42](https://quality.arc42.org/articles/iso-25010-update-2023); ISO/IEC 25023
applicability study, [arXiv 2108.02921](https://arxiv.org/abs/2108.02921);
ISO/IEC 5055:2021, [ISO](https://www.iso.org/standard/80623.html) and the
[CISQ standards page](https://www.it-cisq.org/standards/code-quality-standards/);
SIG maintainability model, Heitlager, Kuipers, Visser 2007,
[A Practical Model for Measuring Maintainability](https://www.softwareimprovementgroup.com/wp-content/uploads/APracticalModelForMeasuringMaintainability.pdf),
and the [SIG/TÜViT evaluation criteria](https://www.softwareimprovementgroup.com/wp-content/uploads/SIG-TUViT-Evaluation-Criteria-Trusted-Product-Maintainability-Guidance-for-producers.pdf);
SonarQube [metric definitions](https://docs.sonarsource.com/sonarqube-server/9.9/user-guide/metric-definitions);
Maintainability Index critique, [van Deursen 2014](https://avandeursen.com/2014/08/29/think-twice-before-using-the-maintainability-index/);
OWASP AISVS Appendix C, [GitHub](https://github.com/OWASP/AISVS/blob/main/1.0/en/0x92-Appendix-C_AI_for_Code_Generation.md).

**Which metrics predict effort and defects.** Chowdhury, Uddin, Holmes, MSR 2022,
[arXiv 2205.01842](https://arxiv.org/abs/2205.01842); Tornhill, Borg, Code Red,
[arXiv 2203.04374](https://arxiv.org/abs/2203.04374), with follow-ups
[arXiv 2401.13407](https://arxiv.org/abs/2401.13407) and
[arXiv 2408.10754](https://arxiv.org/abs/2408.10754); Lavazza et al., JSS 2023,
[ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0164121222002370);
Wyrich et al. 2023, [arXiv 2303.07722](https://arxiv.org/abs/2303.07722);
Majumder et al., EMSE 2022, [Springer](https://link.springer.com/article/10.1007/s10664-021-10068-4);
Nagappan, Ball, ICSE 2005, [Microsoft Research](https://www.microsoft.com/en-us/research/publication/use-of-relative-code-churn-measures-to-predict-system-defect-density/).

**Grading agent-written code.** SlopCodeBench, [arXiv 2603.24755](https://arxiv.org/abs/2603.24755);
SWE-CI, [GitHub](https://github.com/SKYLENAGE-AI/SWE-CI); chained tasks,
[arXiv 2606.21804](https://arxiv.org/abs/2606.21804); code cleanliness and Claude
Code, [arXiv 2605.20049](https://arxiv.org/abs/2605.20049); Code for Machines,
[arXiv 2601.02200](https://arxiv.org/abs/2601.02200); Chen, Jiang, SANER 2025,
[arXiv 2410.12468](https://arxiv.org/abs/2410.12468); design issues in AI IDE
projects, [arXiv 2604.06373](https://arxiv.org/abs/2604.06373); differential
testing of plausible patches, [arXiv 2503.15223](https://arxiv.org/abs/2503.15223);
UTBoost, [ACL 2025](https://aclanthology.org/2025.acl-long.189/); Debt Behind the
AI Boom, [arXiv 2603.28592](https://arxiv.org/abs/2603.28592); AI IDEs or
Autonomous Agents, [arXiv 2601.13597](https://arxiv.org/abs/2601.13597); agent
refactoring, [arXiv 2511.04824](https://arxiv.org/abs/2511.04824) and
[arXiv 2601.20160](https://arxiv.org/abs/2601.20160).

**LLM judges.** Wang et al., ISSTA 2025, [arXiv 2502.06193](https://arxiv.org/abs/2502.06193);
TOSEM review, [arXiv 2510.24367](https://arxiv.org/abs/2510.24367); Don't Judge
Code by Its Cover, [arXiv 2505.16222](https://arxiv.org/abs/2505.16222); Bias in
the Loop, [arXiv 2604.16790](https://arxiv.org/abs/2604.16790); TRACE,
[arXiv 2603.24586](https://arxiv.org/abs/2603.24586); Reliability without
Validity, [arXiv 2606.19544](https://arxiv.org/abs/2606.19544); multi-judge
co-creation, [arXiv 2604.27727](https://arxiv.org/abs/2604.27727).

**Method.** Miller, Adding Error Bars to Evals, [arXiv 2411.00640](https://arxiv.org/abs/2411.00640);
evalci, [arXiv 2607.04429](https://arxiv.org/abs/2607.04429); Beyond Pass@k,
[arXiv 2608.14711](https://arxiv.org/abs/2608.14711); tau-bench,
[arXiv 2406.12045](https://arxiv.org/abs/2406.12045); harness drift,
[arXiv 2607.03691](https://arxiv.org/abs/2607.03691); AI Agents That Matter,
[arXiv 2407.01502](https://arxiv.org/abs/2407.01502); HAL,
[arXiv 2510.11977](https://arxiv.org/abs/2510.11977); Coding Agents Have
Converged, [arXiv 2609.17394](https://arxiv.org/abs/2609.17394).

**Rules files.** ETH Zurich, Impact of AGENTS.md, [arXiv 2601.20404](https://arxiv.org/abs/2601.20404);
instruction adherence factorial, [arXiv 2605.10039](https://arxiv.org/abs/2605.10039);
Show and Tell, [arXiv 2511.13972](https://arxiv.org/abs/2511.13972); static
analysis as a feedback loop, [arXiv 2508.14419](https://arxiv.org/abs/2508.14419).

**Jev.** TypeSafe, [Introducing System One Models and Jev](https://typesafe.ai/blog/introducing-system-one-models-and-jev);
[The Register](https://www.theregister.com/ai-and-ml/2026/09/16/typesafe-ai-debuts-model-for-machines-that-plays-doom/5296711);
Arize, [Can decision models replace LLM judges](https://arize.com/blog/typesafe-jev-llm-judge/);
LangChain, [Can Jev be a better agent evaluator](https://www.langchain.com/blog/jev-agent-evals-langsmith);
Agent Journal, [one judge call or twelve dimension scores](https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/);
limits per [OpenTweet](https://opentweet.io/jev/limits).

The numbers cited for the current plugin: python-0.2.2 review-full at 106 · 106 ·
104 of 110, recall 218/222, $35 for three runs; scoped reviews $1.38 to $5.75 per
run in the 0.2.0 baseline. Experiment 7's budget scales the Sonnet cells by list
price: Opus cells about 2.5×, Fable cells about 5×.
