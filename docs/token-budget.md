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
Measured, on the baseline recorded at b56f79b (`go-2.13.2-b56f79b` in the evals
repository), against 2.11.0: the red-lint quickfix billed 24.3M tokens against 22.5M,
its work moved from three agents into the parent, which made 207 calls at a mean
context of 181k tokens and ran out of turns; the refactor cases that spawned no agent
on 2.11.0 now run the review pass inside their fix loop, sometimes three times
(case D: 0 agents to 7, 0.8M to 5.3M; the centerpiece: 1 to 7, 4.7M to 14.4M; case F:
5.1M to 16.3M with 57 edits by the parent). The 20M class did not disappear; it
changed hands. The diagnosis stands — an unbounded agent is expensive — and the cure
was wrong: the parent is the most expensive context there is. S10 is the cure.

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

### S5 — four rule-family hunters

Twelve single-obsession hunters were designed for models that needed a narrow brief.
Measured after S1 to S4, subagents were still 56 percent of the review tier's spend,
and the whole-repository review spawned up to twelve hunters over one bundle, each
re-billing its own context every turn: the biggest lever left. The hunter-count
experiment has three arms, twelve hunters, four cluster hunters, and one hunter with
the whole rulebook; the four-hunter arm is the one built, and the twelve-hunter arm
is the S1 to S4 run it is measured against. The one-hunter arm is not built.

The pre-commit-review skill spawns one hunter per rule family with any pre-filter
hit, four at most:

| Hunter | Rules | Family |
|--------|-------|--------|
| types | R1, R2, R11, R12 | primitives, validation, enums and sentinels, options |
| structure | R3, R4, R5 | package, file and function shape |
| tests and dependencies | R6, R7, R8, R10 | tests, globals, dependency injection, dependencies |
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
by decision, proved on the review tier alone, three runs of the whole-repository
review per arm on Sonnet 5 against the S1 to S4 run and the pre-S1 baseline.

The four-hunter arm passed both gates. Its recall sits in the baseline band, 107,
104 and 101 of 111 graders with the baseline at 103 to 105 and the twelve-hunter
run at 110; its worst run bills 4.63M tokens against the baseline's best 8.45M, a
45 percent cut, and under the S1 to S4 mean of about 6.6M. Two adjustments were
made on the way and stay: the hunter's budget scales with its rule count, one call
per rule beyond the first reserved for that rule's questions before any further
reading, because a four-rule hunter on a fixed seven-call budget reported
`not reached` on its last rule; and the rule that does not read gets a
`rule unreadable` line in its tally's place, rendered as partial coverage.

A six-hunter variant was built and measured in the same way, and rejected. The two
four-rule families were split, types into types and dispatch and mutation, tests and
dependencies into tests and state, no family over three rules, on the reading that
rule load per hunter was the ceiling. It was not: six hunters scored 109, 104 and
101, the same mean and the same floor as four, and the misses moved rather than
closed, a two-rule hunter dropping a plant that a four-rule hunter had found. Six
hunters billed 26 percent more, and the extra went to the overabstraction skeptic,
which read one file per extraction proposal and hit forty turns in two runs, not to
the hunters. The miss traces agree across both arms: a hunter that judges a plant
from grep context instead of reading the file is what every `not reached` line
describes. The next levers are therefore a turn budget on the skeptic and a
read-before-judge rule for the hunters, not the hunter count. The per-rule half of
the experiment, that page's experiment 4, stays open: the cost per rule the spend
report already gives, then one rule ablated at a time by rendering a plugin without
it.

### S6 — the mechanical questions become a program

A Go analyzer, `ldd-lint` *(planned)* under `tools/`, answers the falsifying
questions that are AST facts: package-level mutable state and manufactured root
contexts (R8), test placement (R7), function and file length (R3), the mechanical
halves of concurrency safety (R10) and mutation discipline (R12). It emits findings
with a rule code and a `file:line`, runs as a hook and in CI at zero tokens, and
replaces the grep behind a question's detect line, writing the same hits table S8
introduces. The hunters for those rules
become verifiers of the analyzer's findings, or go away under S5.

Expected: the greps themselves are 1 percent, so the direct saving is small; the
value is that whole rules leave the hunters' rulebooks, which lands under S1 and S5, and that
the same checks run in CI on repositories without the plugin, beside the handbook
described in [handbook.md](handbook.md). That pairing, the handbook plus the rule
greps wired into golangci-lint and ruff or hooks at zero model cost, is the
handbook-plus-lint-gates arm of [eval-return-experiments.md](eval-return-experiments.md);
this analyzer is the mechanism behind it. Like S5 it runs only after that order's
gate 1.

### S7 — the skeptic's budget holds

The overabstraction skeptic has stated a budget of one Bash call per finding since
S1, and it did not hold. Read on the three whole-repository runs of the four-hunter
proof of S5, the skeptic took twelve findings each time and ran 17, 32 and 24 turns,
one tool call a turn. The two long runs opened 17 and 20 repository files whole with
Read, which the budget did not count, to reach call sites the findings already cited
by line; the short run kept to Bash and still spent a call per file rather than per
finding. Each run pulled 20k to 22k tokens of tool output into the skeptic's context,
most of it those whole files, re-billed on every later turn; the report it returned
was 2.5k to 2.9k tokens, a paragraph of argument per verdict. Under six hunters it
reached forty turns twice, the harness's ceiling and not its own. After S5 it is the
largest single line in a whole-repository review.

Three changes, in the skeptic's agent file and the step that spawns it. The budget
counts every tool call: the first turn reads the doctrine in one command, then one
inspection call per finding, a grep with context that prints the usage count and
the call sites together, findings that share a file sharing a call, then the
verdicts, about N+2 turns for N findings; a whole-file Read is never the way to a
call site. The spawn prompt numbers the findings with file-mates adjacent and states
N and the budget in one line. The report is verdict lines only, evidence inside the
parentheses, a cheaper alternative on one more line, about 2k tokens for a dozen
findings. Behind the stated budget sits a turn ceiling in the agent's definition,
twenty turns, which the harness enforces: an agent that reaches it returns what it
has, marked partial, with no closing turn, so the ceiling is a backstop above the
budget and never the budget, and a report it cuts before the verdicts ships every
finding as proposed, `skeptic: not reached` under `PARTIAL coverage`.

Expected: the skeptic's turns from 17 to 32 down to about 14, the tool output it
carries from about 20k tokens to what a dozen greps with context print, its report
from about 2.7k tokens to about 2k, and the per-agent table showing no Read calls
above the count of findings. The trace does not separate one subagent's bill from
another's, so the skeptic's share is read from its turns and the subagent line as a
whole. Cases that must not move: the extraction graders on the whole-repository
review, the verdicts in kind, the clean-tree controls. The signal to watch is a
refutation turning into a `not reached` line, which the report header shows.

Measured, three whole-repository runs against the four-hunter run it follows. Gate 1
holds: 105, 102 and 110 of 111 graders against 107, 104 and 101, the 110 tying the
twelve-hunter run's ceiling; every finding sent was verified, no `not reached` line
in any run, and every miss is a hunter's, a plant the skeptic was never sent. The
mechanism is gone: the skeptic ran 21, 8 and 4 turns, median 8 against 24, with no
Read call in any run against a median of 17, tool output of about 14k tokens against
22k, and reports of 1.5k to 1.9k tokens in the verdict-line shape. Two of its budget
claims did not hold as written: the 21-turn run spent a call per file on its first
pass and a second pass of single greps, above the N+2 the budget states, and the
twenty-turn ceiling in the agent's definition did not stop it, so the harness
version the evals run on either does not enforce the field for a plugin's agents or
counts turns differently, and the ceiling is declared but not relied on. The 4-turn
run batched fourteen findings into four greps and returned six `N/A` verdicts, three
for R2 construction mechanics and three for R10 lock fixes that name no owner type,
findings the parent sent against the reference's own exclusion; step 3 now states the
exclusion inline, and the skeptic has an `N/A (no extraction)` line for what still
arrives. Gate 2 per case does not hold at three runs: 5.48M, 4.06M and
5.07M billed tokens against 4.63M, 4.44M and 4.00M, the worst new run above the
best old one, and the tier up 12 percent. The extra is not the skeptic's: the
comment critic ran 12 to 15 turns with about 52k tokens of tool output against 9 to
10 turns and 29k, and the hunters' tool output rose by a quarter, both untouched by
this stage and both inside the 2.1x run-to-run swing the problem section records.
The skeptic's saving, some sixteen turns of a 50k-token context, is under that
noise at three runs; the stage removes the mechanism it names and does not move the
bill it can be measured by, and the critic's sweep is the next line to bound.

### S8 — the review's mechanics become scripts

After S1 to S7 the agents are bounded and what the review still pays for is the
parent following recipes. Three of them are deterministic and run on every review,
composed by the model from prose each time: the pre-filter, which prints the
Falsifying questions section of all twelve rules into the parent's context, about
10k tokens carried for the rest of the session, and runs the detection commands it
finds there; the scope bundle, the `mktemp`, `files.txt`, `diff.patch`, one
numbered file per source file and `dirs.txt`, whose recipe S4 had to keep inline
because every review needs it first; and the reconciliation, the `Hunters:` header
that compares each hunter's receipts with the pre-filter's counts by the parent's
reading. The hunters then run the same detection commands a second time, each over
the whole scope in its first labelled Bash call, and the comment critic sweeps the
scope for comments on its own; S7's proof measured that sweep at about 52k tokens of
tool output. Every one of these steps has also failed as prose at least once on the
record: the R2 question the baseline's parent covered only by an improvised grep,
the critic skipped in one of three S5 runs, the skeptic's Reads its budget did not
count. A procedure the model paraphrases is a procedure that drifts.

The plugin already ships the pattern. R9's gate is `check-repo-brain.sh`, a core
template rendered per binding with the language adapter as an include and tested by
its own fixture matrix; the package-size gate is a hook. S8 adds two scripts of the
same shape under the plugin's scripts directory, and the machine-readable contract
they need in the rules' question files.

**ldd-scope** (`scripts/ldd-scope.sh` in every plugin) writes the bundle from the
review's scope rung — an explicit file list, the working tree against `HEAD`, the
branch against its base, or the whole repository — and prints one summary line:
files bundled, files listed with a not-bundled reason, the diff's size, the comment
lines found, the bundle path. It also writes `comments.txt`, the comment lines the
critic judges: the diff's added lines that carry the language's comment marker, plus
every comment line of an untracked file, minus directive lines; so the critic reads
one file instead of sweeping the scope. The bundle recipe leaves the skill; the
summary line replaces it.

**ldd-detect** (`scripts/ldd-detect.sh` in every plugin) runs every falsifying
question's detect line over the bundle's scope and writes two tables: `hits.tsv`, one
row per hit with rule, question, kind, file, line and the matched excerpt, capped per
question with the overflow counted in a row of its own; and `counts.tsv`, one row per
question with its hit count. It prints the counts table, about 300 tokens, and the
per-family totals the spawn step needs. The suppression scan the skill runs in step 1
is a `SUPPRESS` row of the same table. What runs comes from the rules, not from the
script: each numbered question in the bindings' question files and in the core
defaults carries one **detect line** beside its prose, of one of four kinds.

| Detect line | What the script does |
|---|---|
| `Detect-grep: PATTERN [files=src\|test\|all] [exclude-path=ERE,…] [context=n]` — the pattern an ERE in backticks | `grep -nHE` over the scope's source files — the non-test ones unless `files=` says otherwise, minus paths matching an `exclude-path` entry; `context` appends the next n lines to each hit's excerpt |
| `Detect-path: PATTERN` | the pattern over the scope's relative paths: layer directories, role-named packages |
| `Detect-gate: Q<n>` | the R9 gate's `[Q<n>]` report lines, from one run of `check-repo-brain.sh` over the repository |
| `Detect: judgment` | no mechanical lead; the hunter runs the prose, as it does for a question whose only procedure depends on an earlier hit (R1's second question) or on a read |

A pattern is a literal: the placeholder forms the prose used to carry — `<changed
files>`, `$(git diff --name-only …)`, `<Type>` — are gone from the detect lines,
because the scope is the script's. The prose Detection and Violation text stays,
because it is what the hunter reads to judge a hit; the detect line is the lead
generator, and it never changes what the question asks. The core defaults carry a
pattern only where it is language-neutral and `judgment` otherwise, so a Go library
name never sits in core; the language spellings live in the Go and Python bindings'
files. The handbook extracts only the questions' bold headlines, so it does not
change. Both scripts read one include, `scripts/ldd-lang.sh`, for everything the
language decides — the source glob, what a test file is, the suppression directive,
the comment marker and its directive forms; the generic binding's include detects
the language from the repository's marker file and takes the glob as an argument
when there is none.

The generator's `lint-core` check holds the contract: every question carries exactly
one detect line, its kind is one of the four, a `grep` or `path` pattern compiles
and carries no placeholder, its flags are the three named, and every binding that
renders a rule renders the same number of questions as the core default. A fixture
test in the shape of the R9 gate's matrix, `scripts/ldd-detect_test.sh`, runs every
pattern over a small tree per binding and fails on a pattern that does not run, a
planted hit that does not fire, or two runs whose counts differ; the eval manifests,
153 plants and controls per suite, remain the recall test of what the patterns find.
The classification the pass produced, per binding:

| Binding | grep | path | gate | judgment |
|---|---:|---:|---:|---:|
| Go | 36 | 2 | 4 | 28 |
| Python | 37 | 2 | 4 | 27 |
| generic (core defaults) | 17 | 2 | 4 | 47 |

The review skill runs on the two scripts (the stage shipped in two halves: the
scripts first with the skill unchanged, so no eval behavior moved before the rewiring
was proved, then the rewiring). Step 1 is one Bash call that runs both and prints the
counts table, in place of the twelve-section dump and the improvised greps; the
suppression check is the table's `SUPPRESS` row. Step 2 hands each hunter its family's
rows of the hits table, its rules' rows of the counts table and the bundle; the hunter
runs no detection command, its receipts carry the counts table's numbers, and its work
is the judgment the prose describes on each hit, plus the judgment questions, which it
runs by reading as before. A family with no hit in the table gets no hunter, as a
rule with no pre-filter hit got none before; a family with one gets a hunter carrying
every rule file of the family, the hitless ones included, so a rule whose only
violations are judgment questions (R3's function size, R12's aliased constructor
argument) is still read wherever its family is. The script writes the hits table
twice, capped per question for the hunter's first turn and uncapped as
`hits-all.tsv`, so a capped question's remaining hits are one more `awk` and no
hunter runs a pattern of its own. On a scoped review the detection script keeps only the R9 gate's rows about the
scope's own files, so repository-wide doc drift does not spawn the documentation
hunter on every file review. Each line of `comments.txt` carries the code line below the comment — the
declaration it documents — so the critic settles most comments from the inventory
and opens a scope file only for the ones it does not. The `Hunters:` header keeps its shape and its numbers now come
from the counts table against the hunter receipts, so a hunter that reports fewer
hits judged than the table counted renders `PARTIAL coverage` mechanically. The
critic reads the bundle's `comments.txt` as its inventory and opens a scope file only
to judge a comment in context. The report contract the graders read does not change.

What this stage buys is measured in two places. Tokens: on a scoped review the main
thread is 75 to 85 percent of the bill and the step 1 dump alone is about 10k tokens
re-billed on every later call, so Cases A to F should fall 10 to 15 percent; on the
whole-repository review the hunters' detection calls and the critic's sweep go, a
smaller share of a run the agents still dominate. Determinism: the counts table is a
function of the tree, so two runs on the same scaffold produce byte-identical
tables, and a question with no pattern is visible in the table as judgment rather
than silently skipped, which is the failure class #63 closed by hand for one rule.

S8 changes how the review finds leads, not the plugin's shape, so it does not wait
for gate 1 of [eval-return-experiments.md](eval-return-experiments.md). It is also
the seam S6 needs: the analyzer, when it comes, replaces a detect line's pattern with
its own output for the questions that are AST facts and writes the same hits table,
so S6 changes rules and one script and touches no skill.

Expected: Cases A to F down 10 to 15 percent each; the whole-repository review down
about 5 to 10 percent, mostly hunter tool output and the critic's sweep; hunters with
no detection Bash call in the per-agent table; critic tool output under 30k tokens;
two runs on one scaffold with identical counts tables. Cases that must not move:
every review case's graders, the whole-repository recall in the S5 band, the
report-header and cluster graders, the clean-tree controls. Proof: review tier,
the whole-repository review three times and Cases A, B and F twice, about $25,
against the S7 runs.

Measured, on this machine, the whole-repository review four times and Cases A, B and
F twice on the rewired plugin, against the S7 and S9 runs for the whole repository
and against Cases A, B and F run twice on the scripts-only head (the S8a commit,
whose skill was the S9 one) for the scoped cases. A branch review before the proof
found five gaps between the scripts and the review's real invocations — a file named
on a clean tree gave the critic no comments, a directory argument printed "nothing to
review", the current-PR rung was handed as a file list, a question whose hits were
all judgment lost its rule, and a capped question's overflow had no reader — and the
first proof round found two more: the Go R8 lead for a test that mutates a global
carried a typo and never fired, and the parent rendered a refuted extraction as its
Polish alternative alone. Gate 1 holds: 106, 107, 109 and 107 of 114 graders on the
whole repository (the band is the S5 one at 111 graders, three added since),
Case A 13 and 11 of 13 against 11 and 11, Case F 14 and 14 of 14 against 14 and 14,
Case B 14 and 14 of 15 against 15 and 15 — the one grader is a regex for `dial(` and
the report names the same finding with `dial` in backticks; the cluster graders miss
as they did in S7 and S9. The mechanism is gone: no hunter ran a detection command in
any run, two to twelve tool calls each; the critic's tool output on the whole
repository was 45k, 38k and 47k tokens with the plain inventory and 29k once each
comment line carried its declaration, 5k to 12k on the scoped cases, against S7's
51k and 54k. Two things the pre-filter used to skip now run: every scoped review
spawns the critic (the scripts-only arm skipped it on both Case A runs and one Case
B run, on a clean tree) and the documentation hunter, because the R9 gate's rows are
repository-wide. Billed tokens: Case A 1.37M and 1.30M against 1.77M and 1.61M, Case
F 2.43M and 1.95M against 2.57M and 3.45M, both clearing worst-against-best; Case B
1.33M and 1.23M against 2.04M and 1.23M, the worst run 8 percent above the best; the
three cases together 9.6M against 12.7M, down 24 percent. The whole-repository review
billed 4.75M, 4.37M, 4.85M and 4.34M against S7's 5.48M, 4.06M and 5.07M and S9's
4.97M, 4.16M and 5.86M: the mean down 6 and 8 percent, the worst run above the best
of either, so per case the gate does not clear at these run counts. A third round
after the gate rows were scoped to the review's own files ran Cases A, B and F
twice more: 11 and 11, 14 and 15, 14 and 14 graders — the `dial(` grader back, the
skeptic's data-clump grader flipping once — with one hunter on Case A where two had
run, and 1.23M, 1.00M, 1.37M, 1.49M, 2.51M and 1.78M tokens, 9.4M for the three
against the reference's 12.7M, down 26 percent; Case B alone still does not clear
worst-against-best, its best reference run having skipped the critic. The proof
cost about $57 with the three rounds. The baseline recorded on the merged head
(`go-2.13.2-b56f79b` in the evals repository) then showed the class the branch review
had named, twice: a judgment question is read only where its family has a mechanical
hit, so Case C's flag loop was missed when R3's lead did not match the tuple form
`:= false, false`, and the mutation review never reached R7 Q7, `judgment` in every
binding, because the tests family had no hit over the leaf files. Both got a lead: the
tuple form for R3, and for R7 Q7 a boundary comparison in production code — a `<=`,
`>=` or length check against a literal or a length — the hand check's own starting
point.

Risks: a detect pattern wider than its prose floods the hits table, so hits are
capped per question and the overflow count is itself a lead; a question marked
judgment loses the improvised grep a hunter used to run for it, so the eval
manifest's per-rule recall is read per rule after the change and a drop names its
question; the generic binding detects the language at run time, so its scripts take
the source glob as an argument where the Go and Python renderings carry it as a
scalar.

### S9 — the critic reads the scope in chunks and reports what changes

The comment critic's turns were bounded by S1, from 75 on the baseline to 8 to 15
since, and two mechanisms remain, both read on the whole-repository runs of S5 and
S7. First, the critic opens the scope in one call: one `cat` of every numbered scope
file, or one grep with context over all of them written to a scratch file. The
harness spills a result that size to a file and hands back its path, and the critic
then reads the file in three or four pages, so the same 29k tokens of source are
billed twice, once as the spilled result and once as the pages, and every page is a
turn; its tool output ran to 36k to 59k tokens on a scope of 29k. Second, the report
writes a block for every comment it judged, KEEPs included: 230 to 280 blocks, 3k to
10k tokens, of which the parent renders the non-KEEP blocks and the tally and drops
the rest; a hundred KEEP blocks written out is the difference between a 3k report and
a 9k one.

Two changes, in the critic's agent file and the two steps that spawn it, the bound
the critic has until S8's scope script writes its comment lines for it. The scope
comes in chunks: on a whole-repository sweep the numbered scope files that carry
comments are read several per call in the bundle's directory order, each call sized
to come back whole, never one dump of the scope and never a Read of a spilled result;
a scoped diff still comes in the first turn as before. The budget counts every tool
call, the first turn then at most four calls scoped or six on a sweep, and the spawn
prompt states how many files carry comments and the budget in one line, from the
review skill's step 3b and the documentation skill's critique step alike. The report
is the blocks that change something and the tally: a KEEP is counted and never
written, evidence one line, proposal at most two.

Expected: the critic's tool output from 36k to 59k tokens down to the scope read once,
about 29k on the fixture; its turns from 8 to 15 down to about 8 on a sweep; its
report from 3k to 10k tokens down to the non-KEEP blocks, about half. The critic is
a tenth of a whole-repository review, so the bill is read alongside and the mechanism
is the gate: the per-agent table showing no Read of a spilled result and no KEEP
block in the report. Cases that must not move: the critic's graders on the
whole-repository review (the caller-must and restated-idiom recalls, the WHY-comment
control), the tally in kind, the clean-tree controls.

Measured, three whole-repository runs against S7 and S5b. Gate 1 holds: 104, 107 and
107 of 111 graders against 105, 102 and 110 and 107, 104 and 101, the floor of 104
the highest of any cluster arm; the critic's four graders passed in every run of
every arm, and the critic was spawned in all three runs where S5b and S7 each
skipped it once. The double read is gone: no Read of a spilled result in any run,
tool output 37k, 34k and 48k tokens against S7's 51k and 54k, the 48k a run that
chunked the test files in with the source. Two expectations did not hold. The turns
did not fall, 15, 9 and 13 against 12 to 15: the page reads went and inventory calls
took their place, one run spending four calls and another six on `find`, `wc` and
`head` over a scope whose file count the prompt had stated, so the agent file now
names `files.txt` as the inventory and forbids measuring the scope. The report did
not halve, 7.8k, 6.6k and 7.5k tokens with 4, 2 and 3 KEEP blocks against 3k to 10k
with a hundred: the KEEP blocks were never the bulk, the 117 to 144 non-KEEP blocks
with their evidence and proposal are, and those the parent renders. The bill did not
fall, 4.97M, 4.16M and 5.86M against S7's 5.48M, 4.06M and 5.07M, and its shape
moved: the subagents' share fell from 66 to 77 percent to 58 to 64 while the main
thread's calls rose from 14 to 16 on S5b to 19 to 24 here, at 80k to 100k tokens of
context each. Each spawn prompt S7 and S9 ask the parent to compose, numbering the
findings, counting the files, stating a budget, is parent work at that context, and
it is the parent's turns, not another agent's, that S8's scripts are for.

### S10 — the refactor loop's worker

The refactor tier is where the parent works hardest: it routes a finding or a lint
escalation to a rule's Fix-pattern move and then applies the move itself, dozens of
Edit calls at a context that reaches 180k to 265k tokens, re-reading rule ranges and
source files between them, and running the review pass again after every fix round.
Every call re-sends the whole context, so the bill is calls times context, and on the
2.13.2 baseline that product was 24.3M tokens for the red-lint quickfix, 16.3M for
case F, 14.4M for the centerpiece — 94.8M over the ten medium runs 2.11.0 did in 65.9M.

No agent framework runs an edit loop that way. Anthropic's guidance, superpowers and
GSD agree on the shape: the orchestrator plans and reads receipts, a fresh-context
worker edits and tests, a broad review runs once after the work lands, and a fix round
gets a scoped check, never a second broad review. They differ on whether the parent
may ever edit; none gives a worker a token cap, and none measures inline against
delegated edits — the proof below does. S3 removed the workers this plugin had because
they were unbounded; S10 puts one back with bounds that are structural, not numeric.

**The worker.** One `move-implementer` agent per slice. A slice is one Fix-pattern
move over at most five files — a finding, a cluster's mini plan, or a lint escalation
with its route; same-shaped moves over different files share one slice when they fit
in five. The spawn prompt carries the move by name, the absolute path of the rule file
and the `sed` range of its Fix pattern section, the file list, the BASE commit, the
test and lint commands, and the report path. The worker reads the range and the files
once, applies the move, runs the focused tests while it iterates and the full suite
once at the end, keeps every test and lint output in a file under the report path and
reads only its tail, and never spawns an agent. Its exits: green, and the receipt;
three attempts at green and still red, and the receipt says `DEFERRED` with the failing
tail; five reads with no edit, or a range that prints nothing, and the receipt says
`NEEDS_CONTEXT` with what it looked for; a sixth file needed, and the receipt says
`PARTIAL` with the files it did not touch. A failure outside the slice is logged
`OUTSIDE`, never fixed. Its delivery is a tested and linted commit: a `GREEN` worker
commits the slice itself, one commit with the move's name as the subject; every other
exit writes the attempt as a patch under the report path and restores the slice's files
to the base commit, so the parent's tree is never left red. The receipt is at most
fifteen lines: `STATUS`, the move, the commit, the files touched with `git diff --stat`,
one test line, one lint line, `OUTSIDE` and `DEFERRED` lines, the report path.

**The parent.** The refactoring skill keeps its routing table and its stopping
criteria and stops applying moves: it composes slices, spawns one worker per slice
(several in one message when they share no file), and reads receipts — the commits
are the workers'. Its
detection re-run is `ldd-detect.sh` over the touched files; its comment critic runs
once per session over the touched files, and not at all when the workflow's Phase 4
review will run it. The workflow's Phase 3 routes escalations to the refactoring skill
as before; Phase 4 runs the review FULL once per slice, fixes through the skill, then
runs one INCREMENTAL pass over the fixed files: `ldd-scope.sh` on those files,
`ldd-detect.sh`, and the counts table compared with the FULL pass's `counts.tsv` —
hunters only for the families whose rows changed, the critic only when the delta's
`comments.txt` has a line — and what that pass still reports is listed under
`REVIEW: findings deferred` in the ship summary. There is no "until clean" loop. The
quickfix command runs at most three Phase 3 to Phase 4 rounds and lists what is left.

**What it does not do.** No token budget, no turn cap: the bounds are the slice (one
move, five files), the attempts (three), the stall exit and the receipt, and a worker
that ends on one of them ends with a receipt the parent can act on. Nothing changes in
the review tier: the hunters, the skeptic, the critic and the scripts are S8's.

Expected: the parent's main-thread calls on the four movers (quickfix, case F, the
centerpiece, case D) fall from 120, 121, 81 and 49 to under 40; its mean context
stays under 120k; the medium tier falls under 65.9M over the ten comparable runs,
toward the program's 35M; verdicts hold (case B, E, prepare-sms, wire-repo-brain
unchanged; C, D, F and the centerpiece inside the three-grader swing; `stop-check`
rendered). Proof: the medium tier once more at b56f79b for the noise floor, then the
four movers twice per arm in three arms — as is, S3's ban reverted with no other
change, and S10 — then the medium tier once on S10. About $150.

Risks: a worker that fixes outside its slice hides a regression under a green suite —
the `OUTSIDE` line and the per-slice `git diff --stat` in the receipt are the check; a
parent that pastes rule text or source into the spawn prompt rebuilds the context it
was meant to shed — the prompt carries paths, ranges and the BASE commit only, and the
spend report's spawn-prompt tokens column is the check; an INCREMENTAL pass that reads
`counts.tsv` from the wrong bundle compares apples with oranges — the FULL pass's
bundle path is carried in the parent's Phase 4 line.

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
| S5 | hunter fan-out | 8.45M best to 4.63M worst, recall in band | none |
| S6 | grep pre-filter, mechanical hunters | enables S1 and S5 | enables CI use |
| S7 | skeptic whole-file reads | skeptic median 24 to 8 turns, Read 17 to 0; run total unmoved at three runs | PREPARE gate, small |
| S8 | pre-filter dump, second detection run, critic sweep, bundle recipe as prose | Cases A, B and F together 12.7M to 9.6M; whole-repository mean 4.9M to 4.6M, worst run not below the best; no hunter detection call; critic tool output 51k to 29k | none |
| S9 | critic reads the scope twice, writes every KEEP | double read gone, tool output 51k to 54k down to 34k to 48k; turns, report and bill unmoved, main-thread calls up to 19 to 24 | documentation skill, small |
| S10 | edit loop in the parent, review inside the fix loop | none | 94.8M to under 65.9M over ten runs; parent calls under 40 on the four movers |

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
