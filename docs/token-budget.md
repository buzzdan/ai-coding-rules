---
type: architecture
description: the token budget — where a plugin session's tokens go, measured on the Go baseline, the staged design that cuts the spend without changing what the rules say, and the two gates (verdicts and spend) every stage must pass to prove it
status: draft
---
# The Token Budget

## Problem, measured

The plugin's behavior is measured by the evals described in [eval-harness.md](eval-harness.md);
its cost was not. The Go baseline go-2.11.0 (39 runs, 131M tokens, $78, Sonnet 5)
carries every trace, and reading them with `scripts/spend-report.py` gives the
picture below. The work the user asked for is a rounding error. Almost everything
billed is the harness re-reading itself.

| Share of billed tokens | review tier | refactor tier | what it is |
|---|---|---|---|
| subagents, all of their own calls | 53% | 34% | rule hunters, skeptic, comment critic, lint-fixer |
| fixed first-call context | 22% | 27% | ~40k tokens of system prompt, tool definitions, plugin descriptions and CLAUDE.md, billed again on every call |
| prior thinking carried in tool loops, estimate drift | 11% | 22% | not attributable to a tool call |
| plugin text in the main context | 9% | 9% | rule files read to build hunter payloads, skill text injected, examples, rule text via `cat`/`sed` |
| the repository work itself | 2% | 8% | source reads, greps, tests, lint output, edits |

The cost model behind the table is the one the API bills: every call re-sends the
whole context, so a token that enters the context at call k is billed on every call
after k. The review tier adds about 2.6M tokens of unique content and bills 65M; the
mean context per call is 115k tokens. Two levers exist, the number of calls and the
size of the context at each call, and the plugin controls both through its
choreography, not through its rules.

Five mechanisms account for the spend:

1. **Hunters read one file per turn.** On the whole-repository review the R1 hunter
   took 59 turns for 47 Read calls, R12 59 turns for 49 reads, the comment critic 75
   turns for 70 reads. Each turn re-bills the agent's whole context, so about 20k
   tokens of unique reading becomes 0.5M to 0.7M billed per agent. Fourteen agents
   read the same 83 files: 233 Read calls, one service file read 16 times by 10
   agents. This is 71 to 81 percent of a whole-repository review.
2. **The parent loads the rulebook to paste it.** The pre-commit-review skill has
   the parent read every rule file, about 35k tokens, to paste into the hunters'
   spawn prompts, then carries all of it for the rest of the session. Each hunter
   prompt repeats its rule, 2.4k to 4.1k tokens.
3. **Skill text is billed on every later call.** Each Skill invocation injects
   3.5k to 5.7k tokens; a refactor run invokes four skills, about 17k tokens, then
   makes 80 more calls.
4. **Turn count on the main thread.** The prepare case made 84 calls at a mean
   context of 115k tokens; the fixed 40k baseline alone cost 3.4M tokens there. The
   five-phase protocol, not the code, sets the call count.
5. **An improvised agent.** On the red-lint quickfix the model spawned a
   general-purpose agent to apply eleven escalations; it ran 132 turns at about 210k
   context, 20M of the run's 22.5M tokens, $7 of $7.75. The command says escalations
   are fixed by invoking the refactoring skill in the main thread; nothing forbade
   the detour or capped it.

Run-to-run spend is noisy: the same case swings up to 2.1x between two runs of the
same plugin (Case B review: 1.27M and 2.67M; the whole-repository review: 8.4M to
13.9M). Tier totals are steadier than cases. The gates below are written for that.

## Design

The rules R1 to R12 do not change. Every stage below edits choreography, the skills,
agents and commands under `core/`, and the three bindings inherit the change through
the generator described in [generator.md](generator.md). The principle is the one the
plugin already states for linters and now applies to itself: measure, do not
choreograph. Deterministic work moves out of prompts; agents get what they need in
one read; every loop has a budget; the evals decide how many agents a review needs.

Each stage is one pull request, compared against the recorded baseline the way
[eval-baseline.md](eval-baseline.md) already compares behavior changes, but the
proofs are bought in pairs, not one per stage. S1 and S2 are proven together on both
tiers, about $58; then S3 and S4 together on both tiers, about $42, cheaper because
the first pair has already halved the review tier. S2 and S4 add almost no behavior
risk of their own, so pairing them with the stage they serve costs no attribution
that is likely to be needed. If the first pair fails Gate 1, the behavior gate below, bisect by running S1
alone on the review tier, about $20. Development and proof are separable: a stage can
be written and left on its branch at no model cost, and proven whenever the spend is
wanted. Where the pairs sit among the value experiments, gate 0.5 of the gated order,
is in [eval-return-experiments.md](eval-return-experiments.md); S5 and S6, which
change the plugin's shape, wait until that order's gate 1 has run.

### S1 — hunters read the scope once

The pre-commit-review skill writes the scope once, before spawning: the file list,
the diff on a scoped review, and one numbered file per source file, because a
falsifying question asks about the file and not the hunk and a finding needs its
line. Deleted, binary, generated and very long files stay in the list with the reason
they were not bundled. Each hunter's first turn reads its rule, the diff and the
bundled files its leads name, in one command, under a ceiling of about 20k tokens;
later reads take the files its detection hits name, several per call; a per-file
Read is for a call site outside the scope. On `--all` every hunter gets its own
reading order over the directories, its rule's pre-filter hits first, so no two
hunters truncate at the same tail. The rule-hunter and comment-critic state a budget
of the first turn plus four calls, six on a whole-repository review, and the skeptic
one call per finding; each states the exit when the budget is spent: receipts for
the commands, which ran over the whole scope in one call, and a `not reached:` line
for what was not read to judge, which the report header renders beside the tally
with a `PARTIAL coverage` marker. The skeptic gets no bundle, since it verifies call
sites across the whole repository. A hunter that spent 50 turns on the baseline
spends about 5.

Expected: the whole-repository review from 8M to 14M tokens down to 2M to 4M; scoped
reviews down 30 to 40 percent. Cases that must not move: every review case's graders,
the recall count on the whole-repository review, the clean-tree controls.

### S2 — rules by reference

The spawn payload carries the rule's path and the pre-filter leads, not the rule's
text. The hunter reads its rule in its first turn, once, in its own context. The
parent never reads a rule file to build a payload; the pre-filter prints every rule's
Falsifying questions section in one command. The skeptic and the comment critic get
their doctrine the same way, as paths with the `sed` range of the section to read,
from every skill that spawns them, so neither reads a 30k-byte rule file whole for a
4k-token section. The parent lists the resolved paths before spawning, and an agent
whose doctrine does not read returns that instead of hunting from memory. The rule-hunter agent's description says the path, not the text. One effect the proof
run made visible: the pre-filter's recall now rests on the rules' own detection
commands, where the baseline's parent, having read whole rule files, improvised greps
that hid a gap; the first such gap, R2's question on upstream validation not naming a
"defensive re-check", was closed in the rule.

S1 to S4 are in the plugin sources and in all three bindings; their proofs, the
procedure under "Proving it", have not run, so their rows in the targets table are
still claims.

Expected: about 6 percent of the review tier, and every hunter prompt shrinks by its
rule. Risk: none to recall, the hunter reads the same text.

### S3 — budgets and the general-purpose ban

The linter-driven-development skill names the agents it spawns — the lint-fixer, and
the skeptic in its PREPARE gate — and says the review agents belong to the skills that
own them; refactoring is a skill invoked in the main thread, never delegated to a
general-purpose or any other subagent. What a lint-fixer's respawn ceiling leaves is
unresolved mechanical lint the ship summary lists, never work for the refactoring
skill or a subagent. The quickfix command repeats it
beside the escalation step, and the refactoring skill says the same of itself. The
lint-fixer states a budget of six lint runs and forty edits per spawn; what its budget
did not reach comes back as `ESCALATED: … → mechanical, budget spent` lines, and the
caller spawns a fresh lint-fixer over those packages rather than letting one context
grow. The spend report's per-agent turn column is the check.

Expected: the 20M-token class of run disappears; the red-lint quickfix returns to
the 2M to 3M its main thread costs.

### S4 — skill text on a diet

The pre-commit-review and refactoring skills were 30k and 23k bytes as rendered. Each
keeps its protocol — the steps, the spawn-prompt items, the report and `Stop check`
contracts the graders read — and moves the long form into its `reference.md`: the
hunt-focus table, agent output shapes, verdict rules, the cluster pass and report
example for the review; the pattern index, file and package routing, preparatory
mode, the stopping criteria in full and the multi-rule procedures for refactoring. Each step names the `sed` range it reads, and the range is printed inside
a Bash call the step already makes — the pre-filter, the bundle write, the loop's first
lint run, the Gates run of the exit — never as a call of its own, because a round trip
at a 115k-token context costs more than any of these sections; only the report's long
form is read on its own, once, before the report is written. Sections a step needs
unconditionally and early, the bundle recipe and the suppression scan, stay inline.
So the text enters the context once and late instead of on every call from the
invocation on. Target: each SKILL.md at or under about 10k bytes
rendered; as landed, both render at about 13k, from 30k and 23k, the remainder being
the routing table, the bundle recipe, the suppression scan, the
spawn-prompt items and the two contracts, which are protocol. The injected text per
invocation falls by more than half.

Expected: about 5 percent of both tiers, more on long runs. Risk: a step that
depended on an example the skill no longer inlines; the medium-tier art judges catch
it.

### S5 — six rule-family hunters

Twelve single-obsession hunters were designed for models that needed a narrow brief.
Measured after S1 to S4, subagents were still 56 percent of the review tier's spend,
and the whole-repository review spawned up to twelve hunters over one bundle, each
re-billing its own context every turn: the biggest lever left. The hunter-count
experiment has three arms, twelve hunters, a few cluster hunters, and one hunter with
the whole rulebook; the cluster arm is the one built, and the twelve-hunter arm is
the S1 to S4 run it is measured against. The one-hunter arm is not built.

The cluster arm was first built as four hunters, types (R1, R2, R11, R12), structure
(R3, R4, R5), tests and dependencies (R6, R7, R8, R10) and documentation (R9). Two
review-tier runs read the same way: the three-rule structure hunter found every
plant once its budget scaled with its rule count, the one-rule documentation hunter
never missed, and the two four-rule hunters, twenty falsifying questions each over
the whole repository, reported `not reached` and dropped plants — the types hunter
lost the three CASE-A plants in one run — while a larger budget did not move them.
The rule load per hunter, not the call count, was the ceiling, so the two four-rule
families were split. The pre-commit-review skill spawns one hunter per rule family
with any pre-filter hit, six at most, no family over three rules:

| Hunter | Rules | Family |
|--------|-------|--------|
| types | R1, R2 | primitives, validation |
| dispatch and mutation | R11, R12 | conditional dispatch, mutation discipline |
| structure | R3, R4, R5 | package, file and function shape |
| tests | R6, R7 | test-only interfaces, test placement |
| state | R8, R10 | globals, shared state and concurrency |
| documentation | R9 | comments and the documentation network, beside the comment critic |

A hunter gets the absolute paths of its family's rule files that had hits, never one
that had none and never a second family; it reads them all in its first turn, whose
ceiling rises from about 20k to about 30k tokens, runs every rule's detection
commands in one labelled Bash call, and returns one receipt per falsifying question
per rule and one tally per rule, so the merged report reconciles per rule exactly as
before. On a whole-repository review its reading order sorts the directories by the
family's combined hits.

Two changes ride along because they touch the same files. The hunter report is
capped: finding blocks, receipts, tallies and the `not reached:` line, about 3k
tokens, where a hunter's report ran to about 10k of narrative the parent dropped. And
the review-only command runs no build, tests or linters: the review reads code, it
does not verify it. The clean-tree review runs had spent about 6M tokens per tier on
the tests and the linter before a review that changes nothing; the analyze command
still runs all three gates.

The stage was gated on gate 1 of
[eval-return-experiments.md](eval-return-experiments.md). The S1 to S4 proof passed
Gate 1 and missed Gate 2's per-tier target, and the stage was built on that evidence
by decision, proved on the review tier alone: the whole-repository review read on its
grader count, where a plant goes missing when a hunter carries too many rules; the
two scoped cases on their graders; Gate 2 per case against the S1 to S4 run and the
baseline. Four hunters billed 45 percent under the baseline's best whole-repository
run and held the baseline's grader band, 101 to 107 of 111, under the twelve-hunter
run's 110; six hunters are the arm that is meant to close that gap at about eight
agents a run against the baseline's fourteen. A hunter's first turn on a
whole-repository review, its rule files plus directories, is the ceiling to watch. The per-rule half
of the experiment, that page's experiment 4, stays open: the cost per rule the spend
report already gives, then one rule ablated at a time by rendering a plugin without
it.

### S6 — the mechanical questions become a program

A Go analyzer, `ldd-lint` *(planned)* under `tools/`, answers the falsifying
questions that are AST facts: package-level mutable state and manufactured root
contexts (R8), test placement (R7), function and file length (R3), the mechanical
halves of concurrency safety (R10) and mutation discipline (R12). It emits findings
with a rule code and a `file:line`, runs as a hook and in CI at zero tokens, and
replaces the grep pre-filter in the spawn payload. The hunters for those rules
become verifiers of the analyzer's findings, or go away under S5.

Expected: the greps themselves are 1 percent, so the direct saving is small; the
value is that whole rules leave the hunters' rulebooks, which lands under S1 and S5, and that
the same checks run in CI on repositories without the plugin, beside the handbook
described in [handbook.md](handbook.md). That pairing, the handbook plus the rule
greps wired into golangci-lint and ruff or hooks at zero model cost, is the
handbook-plus-lint-gates arm of [eval-return-experiments.md](eval-return-experiments.md);
this analyzer is the mechanism behind it. Like S5 it runs only after that order's
gate 1.

## Proving it

Every stage passes two gates on the same run, or it does not ship.

### Gate 1: behavior does not move

The comparison procedure in [eval-baseline.md](eval-baseline.md), unchanged: run
the cheap tier at the baseline's run counts and the medium tier once, regrade both
sides with the same graders, and no case may move by more than one flipping grader;
the whole-repository review is read on its grader count inside the baseline's band;
art judges pass on the same cases.

### Gate 2: spend falls, beyond the noise

The measure is billed tokens, the sum the API reports of input, cache reads, cache
creation and output, over the whole run including subagents. Dollars are recorded
too but change with cache pricing; tokens do not.

- **Per case**, a saving is claimed only when the new arm's worst run bills fewer
  tokens than the baseline's best run of that case. That clears the 2.1x swing
  without a variance model.
- **Per tier**, the total over identical run counts must fall by at least the
  stage's stated target. The review tier's baseline is 65.6M tokens over 29 runs,
  the refactor tier's 65.9M over 10.
- **Per agent**, the spend report's turn and Read-call columns must show the
  mechanism the stage claims to remove is gone: a hunter at 5 turns, not 50; no
  general-purpose agent above its budget.

Gate 1 of [eval-return-experiments.md](eval-return-experiments.md) carries a cost
bound, and it uses this page's definitions: billed tokens as the measure, and the
worst run of the new arm against the best run of the baseline as the rule.

### The instrument

`scripts/spend-report.py` is the reference implementation and produced every number
on this page: per run, billed tokens, cost, main-thread calls, mean and peak
context, agents and their share; per tier, the attribution table above; per agent
kind, turns, Read calls, prompt and result tokens. It reads the traces a run or a
baseline already records, so the baseline's spend is measurable today, before any
stage lands.

The same report belongs in the runner described in [eval-runner.md](eval-runner.md),
which already parses the trace for cost and turns: `billed_tokens`, `main_calls`,
`mean_context`, `agents` and `agent_tokens` recorded in each result and summed in the
aggregate, and a spend table in every baseline README beside the pass rates
*(planned; ldd-eval spend)*. Until then the script runs over the results directory
and its markdown output goes into the pull request.

### Procedure per stage

1. Branch, change the core sources, `task generate` for all three bindings, `task check`.
2. Run the cheap tier at the baseline run counts and the medium tier once against
   the generated Go plugin, model pinned, cap set, `--keep-temp`. About $58 for the
   S1 and S2 pair, about $42 for S3 and S4; less as stages land.
3. Regrade baseline and arm with the current graders. Gate 1 per case.
4. Spend report on both. Gate 2 per case, per tier, per agent.
5. Both tables in the pull request. On acceptance, promote the run as the next
   baseline with the spend section in its README, so the following stage compares
   against it.

### Reference floors

Two more arms run once, not as stages but as the outer bounds of the question the
design answers: the handbook alone, `coding-rules/go.md` as generated, imported from
the fixture's CLAUDE.md with no skills or agents, never a hand-condensed summary; and
no plugin at all. Their recall on the whole-repository review is the floor the
harness must beat to justify any token at all; their spend is the floor the stages
approach. If the handbook arm's recall is inside the noise floor of the plugin's, the
handbook is the product and the remaining choreography is the cost. Experiment 8 of
[eval-return-experiments.md](eval-return-experiments.md) is the same design on
py-mini with a fourth row, none, handbook, handbook plus lint gates, plugin, across
three models; its gate 0.5 runs the three plugin-free cells in parallel with the
diet, since nothing in the diet can change them.

## Targets

| Stage | Mechanism removed | Review tier | Refactor tier |
|---|---|---|---|
| S1 | per-file hunter turns | 65.6M to about 35M | small |
| S2 | rulebook pasted twice | a further 3M to 4M | about 1M |
| S3 | unbounded improvised agents | none | 66M to about 45M |
| S4 | skill text re-billed per call | about 2M | about 3M |
| S5 | hunter fan-out | decided by recall | none |
| S6 | grep pre-filter, mechanical hunters | enables S1 and S5 | enables CI use |

The program's target: the review tier at or under 25M tokens and the refactor tier
at or under 35M, both with Gate 1 clean, against 65.6M and 65.9M today. Each number
is a claim to be proven by the procedure above, not a result.

## Risks

- **Skimming.** A hunter that reads the scope once may report fewer hits per
  question. The receipt lines the rule-hunter agent already requires, hits per
  falsifying question, and the recall graders on the whole-repository review are the
  check; a drop is a Gate 1 failure, and the stage does not ship.
- **Bundle size.** The whole fixture is about 100k tokens; a real repository is
  larger. The bundle is per file, a hunter reads the files its leads and hits name
  under a first-turn ceiling, and on `--all` each hunter's reading order puts its own
  rule's hits first; a review wider than the budget reports the directories it did
  not reach rather than reading past its budget. The detection commands still run
  over the whole scope, so recall from the commands does not depend on what was read;
  what a budget bounds is the judgement of hits, and the `not reached:` line names
  the hits left unjudged.
- **Budgets are prose.** Claude Code agent frontmatter has a `maxTurns` field that
  caps agentic turns, but a hunter it cuts off returns a partial result without its
  receipts, which the report cannot reconcile; so a budget is a stated protocol with
  a stated exit, and the cap is not set. The spend report's per-agent columns are how
  a broken budget is seen, and a run that breaks it fails Gate 2.
- **The fixed context is not the plugin's.** The 40k tokens per call are mostly
  Claude Code itself; the plugin's descriptions are a small part. The stages cannot
  shrink it, only the number of times it is billed.
