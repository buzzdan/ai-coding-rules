---
name: pre-commit-review
description: |
  ADVISORY pre-commit review that orchestrates four parallel rule-family hunters, an over-abstraction skeptic, and a comment critic against the diff.
  Spawns read-only agents (rule-hunter, overabstraction-skeptic, comment-critic); NEVER edits code.
  Invoked by @linter-driven-development (Phase 4), by @refactoring (after pattern application), or manually for standalone code review.
  Categorizes findings as Bugs, New Practice (when in Rome), Design Debt, Readability Debt, or Polish Opportunities. Does NOT block commits.
allowed-tools:
  - Read
  - Grep
  - Bash
  - Agent
---

<objective>
Verify a finished diff against the plugin's rules (R1–R12) with evidence, by orchestrating
four parallel rule-family hunters, one over-abstraction skeptic and one comment
critic — the agents `python-linter-driven-development:rule-hunter`, `python-linter-driven-development:overabstraction-skeptic` and
`python-linter-driven-development:comment-critic`, spawned by those names and no others; a language group
another plugin reviews (step 1) gets that plugin's agents of the same three names, and
this plugin's when that name does not resolve. Pure orchestration
and reporting: this skill spawns agents and reports; it never edits code, never fixes
findings, never blocks a commit. Rule knowledge lives once in `../../rules/`; agents get
the paths of their rules and read them themselves in their first turn — the parent never
pastes a rule, and agents do not invoke skills. Each step's long form is in
`reference.md` here, read by `sed` range inside a Bash call the step already makes —
never the file whole, never a call of its own — except the report's, read once before
writing.
</objective>

<timing>
Run pre-commit, per completed vertical slice — NEVER mid-implementation: GREEN-step TDD
code is supposed to look under-designed. The REFACTOR step's per-cycle greps are the
mid-implementation net; this pass is the verification net on finished work.
</timing>

<inputs>
- **Diff scope**: the caller's resolved rung — explicit files or directories, else
  the working tree's changes against `HEAD` plus untracked files, else the branch
  against its base as a range (`--base <merge-base>`), and the whole repository
  (`--all`) only when asked for explicitly. Step 1 hands that rung to `ldd-scope.sh`,
  which resolves it; the scope is never widened here, and an empty scope is reported
  as "nothing to review", never as a clean verdict. A scope whose files are written
  in several languages is one review: the scope script splits it by the language of
  each file and sends each group to the plugin installed for that language, and the
  report is one report with a section per language.
- **Mode**: `FULL` (first run) or `INCREMENTAL` (re-run after fixes; needs the previous
  report's findings).
</inputs>

<protocol>

<step_1_detection_pass>
In-context, cheap, no agents yet. One Bash command resolves the scope, writes the scope
bundle and runs the detection pass over it — the plugin's two review scripts, never a
recipe or a grep composed here in their place:
`S=<this skill dir>/../../scripts; out=$(bash "$S/ldd-scope.sh" <rung>); code=$?; echo "$out"; case "$out" in *'nothing to review') ;; *) (( code == 0 )) && { B=${out##* }; bash "$S/ldd-detect.sh" "$B" && sed -n '/^## Hunt focus/,/^## Waiting for agents/p' <this skill dir>/reference.md; } ;; esac`
`<rung>` is the scope from `<inputs>` as `ldd-scope.sh` takes it: the explicit files
or directories as arguments (a directory stands for the source files under it),
`--base <ref>` for the branch against its base, `--all` for the whole repository,
nothing for the working tree against `HEAD` with untracked files. The scope script
prints one summary line — files bundled, files listed with a not-bundled reason, the
diff's size, the comment lines found — whose last word is the bundle path `B`; when
it prints `ldd-scope: nothing to review` instead, the review ends with that report.
When the scope spans several languages it prints one such line per **language
group** first — `ldd-scope[d]: …`, `ldd-scope[go via <the Go plugin>]: …`, or `ldd-scope[<id>]: <n> files excluded: no language block matched (.<ext>)` for
a language no installed plugin reviews — and a last line `ldd-scope: <g> language
groups (…) → B` where `B/groups.txt` names, per group, the plugin that reviews it,
that plugin's directory and the group's own bundle. A non-zero exit with no
"nothing to review" line is a scope every installed plugin excluded: report its
stderr (one line per file and why) and stop. The detection script then runs once per
group, under a `== <id> — <plugin> ==` line each, with that plugin's own rules — an
excluded group prints `== <id> — not reviewed: <why> ==` and nothing else — and
everything below is done **per group**: `B`, the rule paths and the agents are that
group's plugin's, and a group whose counts table has no hit spawns nothing and is
reported as such.
The detection script runs every falsifying question's detect line over the scope,
writes `hits.tsv`, `hits-all.tsv` and `counts.tsv` into the bundle, and prints the
**counts table** — one row per question, `rule q kind hits`, a `judgment` row for a
question only a hunter's reading answers — then one line per rule family. That
table, about 300 tokens, is the pre-filter: the parent prints no rule file, composes
no detection command, and never reads a Falsifying-questions section. On a scoped review the R9
gate's rows are the scope's own files' — an orphan doc or an unwired root is the
repository's state, for a `--all` review or BROADER CONTEXT, never this diff's
finding. When the
detection script exits 2 instead — a pattern its grep rejects, the R9 gate failing to
run — the review did not run: report its message, spawn nothing, and never render a
rule as `skipped` or compose the pass by hand. A rule family none of whose rules has
a hit — `0` on every row of theirs that is not `judgment` — is skipped: no hunter for
it.

Also in-context: a new `# noqa`, `# type: ignore`, or `# ty: ignore` in the diff, or a new
`ignore`/`per-file-ignores` entry under `[tool.ruff.lint]` or a new
`[[tool.ty.overrides]]` or `[[tool.mypy.overrides]]` block, is itself a finding — the
change must justify, with evidence, that the rule genuinely does not apply. All three
directives are suppressions: a `# ty: ignore[invalid-return-type]` or a
`# type: ignore[return-value]` on a `return None` silences R1 Q4 as surely as a
`# noqa: PLW0603` silences R8.

The table's `SUPPRESS` row is that check for the directive: it counts the suppression
directives on the diff's added lines (over every scope file when the bundle has no
diff), and a count above zero is one finding per `SUPPRESS` row of `hits-all.tsv` —
the uncapped table, so no directive hides behind an overflow row — anchored at that
row's `file:line`. A new exclusion in the linter's configuration file is still read
from the diff.

Also in-context — the **when-in-Rome check**: anything the diff introduces that the
repo does not already use (a new test mechanism, a dependency in `pyproject.toml`,
a tool or config file, a convention-file edit bundled into a feature diff, a layout
unlike its siblings) is a 🟠 finding when a grep of the repo *outside* the diff shows
zero prior use; the fix is a discussion or a separate PR, never silent inclusion.
</step_1_detection_pass>

<step_2_spawn_hunters>
The bundle exists (step 1 wrote it: `files.txt`, `diff.patch` on a scoped review,
`scope/<path>.txt` per bundled file with the file's own line numbers, `dirs.txt` on
`--all`, `comments.txt`, `hits.tsv`, `hits-all.tsv`, `counts.tsv`); nothing is
written here. One Bash
command, only when the scope is not empty, lists every rule path the prompts will
carry and prints `sed -n '/^## Waiting for agents/,/^## The merged report/p'
<this skill dir>/reference.md` — how agents are waited for, what each returns and what
their verdicts do — so steps 2, 3 and 3b cost no read of their own. The bundle is the
only thing this review writes; hunters and the critic get its path, the skeptic does
not.

Spawn **one rule-hunter per rule family with hits** — four at most, never one per
rule — as **foreground** `Agent` calls (`run_in_background: false`) issued together in
one message, so they run in parallel and return in it. Never wait any other way — no
polling, monitor or wake-up, no second spawn of a call answered "Async agent
launched"; its result arrives by itself ("Waiting for agents", read above). The
families:

| Hunter | Rules | Family |
|--------|-------|--------|
| types | R1, R2, R11, R12 | primitives, validation, enums and sentinels, options |
| structure | R3, R4, R5 | package, file and function shape |
| tests and dependencies | R6, R7, R8, R10 | tests, globals, dependency injection, dependencies |
| documentation | R9 | comments and the documentation network — runs beside the comment-critic (step 3b) |

A family none of whose rules had a hit gets no hunter — its `judgment` rows alone
spawn nothing; step 1's four family lines say which families did. A family with a
hit gets one hunter carrying **every rule file of the family**, the hitless ones
included: their `judgment` questions are read on the ground the family's hits name,
and their mechanical questions receipt `0 hit(s)`. Each spawn prompt MUST contain:

1. **The absolute paths of every rule file of this family** — the hunter's whole
   rulebook, each read whole in its first turn. Never the text pasted; never two
   families in one hunter; the parent reads no rule to build a prompt (step 1
   printed only the counts).
2. **The bundle's absolute path** and the diff scope it holds. On `--all`, also this
   hunter's **reading order**: `dirs.txt` with the directories the family's `hits.tsv`
   rows name first, most rows first, ties by line count ascending, then the rest — no
   two hunters truncate at the same tail.
3. **The family's rows of the hits table**, as the one command the hunter runs in its
   first turn beside its rule files — `awk -F'\t' '$1 ~ /^(R1|R2|R11|R12)$/' <bundle>/hits.tsv`
   with the family's rule ids — and every row of the counts table for the family's
   rules, pasted from step 1's print (about two dozen lines for a four-rule family).
   The counts are the hunter's receipts: it judges every hit the table counted, runs
   each `judgment` question as its rule's prose says, and returns one receipt per
   question carrying the table's number.
4. **The overflow rows**, when the family has any: a row whose file is `-` and whose
   excerpt reads `+N more hit(s) not listed` is a question capped in `hits.tsv`. The
   prompt names each (`R9 Q4: 55 more hits than listed`) and says where the rest are:
   the same `awk` over `<bundle>/hits-all.tsv`, the uncapped table, filtered to that
   rule and question — `awk -F'\t' '$1 == "R9" && $2 == "4"' <bundle>/hits-all.tsv` —
   read in a later call and judged like the rest, so the receipt still carries the
   table's count. The hunter runs no pattern of its own.

Every path is absolute (the hunter runs in the reviewed project's cwd): resolve
`../../rules/R<N>-….md` and any case file the rule cites from this skill's own
location — for a group `groups.txt` gives to another plugin, from that plugin's
directory in the same row, so a Go group reads the Go plugin's rules and a Python
group the Python plugin's — then `ls` every resolved path before spawning — listing is not reading; a
path that does not list is fixed here, never handed to a hunter. Each hunter returns
finding blocks (`rule | file:line | evidence | fix pattern | effort`), one receipt per
falsifying question of each rule it was given (`R<N> Q<n>: <hits> hit(s) → <findings>
finding(s)` with the counts table's number; `R<N> Q<n>: judgment → <findings>
finding(s)` for a judgment question; `R<N> Q<n>: <judged> of <hits> hit(s) judged →
<findings> finding(s)` when its budget ended before every hit was read), one tally
per rule — or, for a rule file that did not read, `R<N>: rule unreadable at <path>`
in the tally's place — and, when its budget ended the hunt, one `not reached:` line.
A question with no receipt was not run. Findings, receipts, tallies (or unreadable
lines) and that line are the whole report, about 3k tokens; a hunter returns no
narrative ("Hunter output", read above).
</step_2_spawn_hunters>

<step_3_skeptic_pass>
Collect every finding whose fix is a new type or package — R1's Replace Primitive
with Domain Type, Introduce Parameter Object, Name the Container and Name enum
strings, R4's promotion to a
package, R10's Extract Synchronized Owner when it names the owner type, R11's
Interface Dispatch and Strategy Map — and no other. Never an R2 construction
mechanic (a validating constructor, underscore-prefixed fields, an options type and its
`With*` functions, a Null Object default), never an R10 fix that is a lock taken or a
write moved under one, never a fix that is a rename, a deletion or a test: those
propose no type, and they go straight to the report. Spawn one
overabstraction-skeptic, foreground, in a message with no hunters in it, after every
hunter result is in hand; the critic (step 3b) shares that message. Its spawn prompt
MUST contain:

1. The extraction findings under review — the hunter blocks pasted verbatim,
   numbered, findings that share a file or a package adjacent, so one inspection call
   verifies them together.
2. The absolute path of `../../rules/R1-primitive-obsession.md` and the range it reads:
   `sed -n '/^### Juiciness scoring/,/^### Placement/p'`. Never the file whole.
3. The absolute path of `../../examples/overabstraction-cidr.md`; with R11 dispatch
   proposals under review, also `../../examples/anti-if-dispatch.md` and
   `../../examples/switch-to-polymorphism.md`.
4. The count and the budget it fixes, in one line: `N findings — budget: the first
   turn, then one inspection call per finding (every tool counts; findings sharing a
   file share a call), then the verdicts. Report verdict lines only.`

No bundle: the skeptic verifies call sites across the whole repository. Its verdicts
(`CONFIRMED (score N …)`, `CONFIRMED (score N, judgment call) — alternative: …`,
`REFUTED (score N …) → cheaper alternative`, `N/A (R2 mechanism)`, `N/A (no
extraction)`, `skeptic: not reached`) are carried into the report verbatim, score
included; a report its turn
ceiling cut off before the verdicts carries none, and every finding sent then ships
as proposed with `skeptic: not reached`. What never goes to it (R2's construction
mechanics, non-extraction findings) and what each verdict does: "Skeptic verdicts",
read in step 2.
</step_3_skeptic_pass>

<step_3b_comment_critic>
When the scope carries comment lines — step 1's summary line says how many, and
`comments.txt` in the bundle holds them as `file:line:text ⏎ code`, the code being the
declaration or statement below the comment: the diff's added comment lines on a
scoped review plus every comment line of a bundled file the diff does not touch,
every comment line of the bundled files on `--all`, minus directives; one line
qualifies, none and the critic is not spawned — spawn one
comment-critic in the same hunter-free message as the skeptic (alone when no skeptic
runs), foreground; it is waited for only by the call returning. Its spawn prompt MUST
contain:

1. The absolute path of `../../rules/R9-repo-brain.md` and the range of its **Comment
   policy** section: `sed -n '/^### Comment policy/,/^### Edge conventions/p'`.
2. The absolute path of `../documentation/reference.md` and the range of its **Comment
   Value Toolbox** catalog:
   `sed -n '/^## Comment Value Toolbox/,/^## Frontmatter Templates/p'`.
   Neither file is read whole.
3. The absolute path of `../../examples/private-comment-noise.md`.
4. The diff scope and the bundle's absolute path: the critic reads
   `<bundle>/comments.txt` in its first turn and opens a numbered `scope/` file only
   to judge a comment in its context. A caller without a bundle omits the path, and
   the critic builds its scope in its first turn.
5. The count of comment lines from step 1's summary line and the budget in one line:
   `N comment lines in comments.txt — budget: the first turn, then at most K calls
   that open scope files for context, several files each (every tool counts; never a
   sweep of the scope), then the verdicts. Report non-KEEP verdicts and the tally.` K
   is four on a scoped diff, six on `--all`.

It returns one block per non-KEEP verdict (`TRIM / REWRITE / DELETE`, `DELETE → route
R3`) with evidence and replacement text, and a tally that counts the KEEPs; non-KEEP
verdicts are 🟡 Readability Debt ("Critic verdicts", read in step 2).
</step_3b_comment_critic>

<step_4_merged_report>
Before writing, read `reference.md`, `sed -n '/^## The merged report/,$p'` — the cluster
pass, the category map, the line shape, the reconciliation and the worked example —
once, now. The contract it spells out, kept whatever the scope:

- **Clusters first.** Before categorizing, list the anchors: group every hunter finding
  — kept, refuted by the skeptic, or never sent to it — by the named thing it is about
  (a type, a function, a discriminator, a package), never by line. An anchor converges
  when ≥2 findings from different rules, or from different falsifying questions of one
  rule, land on it — exported nilable fields, a method re-checking them and a
  None handed to the constructor are three R2 questions on one type, one missing
  constructor. Render every converged anchor, two findings or twenty, as its own entry
  above the categories, titled with the anchor itself:

  ```
  🔗 CLUSTER: Alert.Channel — R1, R11, R2, R7
     Convergence: 4 findings — R1 Q1, R11 Q2, R2 Q2, R7 Q4
     Hypothesis: missing domain concept — a Channel type wants to exist
     Skeptic: CONFIRMED (score 6) · (or REFUTED → the cheaper alternative, the
     convergence still real · or no verdict when no extraction was proposed)
     Routing: design-first — @code-designing (cluster-scoped), then @refactoring
  ```

  The title line carries the anchor and the ids of the rules that converged on it;
  the pass is not done until each anchor two rules converged on has its entry, and a
  whole-repository review commonly has six or more. Members still render under their
  categories, each tagged `[cluster: <anchor>]`.
- **The first line is `📊 CODE REVIEW REPORT`**, then the `Scope:`, `Hunters:`,
  `Skeptic:` and `Critic:` lines as the example shows — before any cluster, never
  under a title of the review's own. A scope of several language groups keeps one
  report: the `Scope:` line names every group and the plugin that reviewed it, and
  the `Hunters:`, `Skeptic:` and `Critic:` lines, the clusters and the categories
  are repeated under one `## <language> — <plugin>` heading per group, in the order
  of `groups.txt`. A group with no hit is one line under its heading — `no hits —
  <n> files` — and an excluded group one line with the scope script's reason; neither
  is ever left out ("Several languages", read in `reference.md` before writing).
- **Categories**: 🐛 Bugs · 🟠 New Practice · 🔴 Design Debt · 🟡 Readability Debt (R3,
  R9, the critic's non-KEEP verdicts) · 🟢 Polish (the skeptic's cheaper alternatives).
- **One line per finding**: `file:line | R<N> Q<n>: evidence in the question's own
  words | the move as the rule's Fix pattern spells it | S/M/L`. Evidence about a
  function, a signature or a call quotes it as the code writes it —
  `dial(host string, port int, tls bool)` — never the bare name. The fix cell names the
  move exactly as the Fix pattern section spells it — `Introduce Parameter Object`,
  `Name enum strings`, `Extract Leaf Type` — and the skeptic's verdict and score follow
  the move in the same cell: `Introduce Parameter Object: Endpoint — skeptic REFUTED
  (score 1) → rename dial to Client.dial`. A verdict never replaces the move name with
  its alternative, and a REFUTED finding keeps its own line under its category — the
  hunter's evidence in the question's words, the move, the verdict — while its
  cheaper alternative ships as a second line under 🟢 Polish; a Polish line alone is
  a finding dropped, and the `Hunters:` count does not count it. A
  count is never a finding — `R9 (46 findings)` is forbidden; findings of one shape may
  share one line naming every anchor. Anchors rendered equal findings returned.
- **One physical line, never wrapped.** A finding line and a cluster title line are
  each one line of text however long — never broken across lines for width. Readers
  grep the report, and a move name or anchor split over two lines is invisible to
  them; length is the renderer's problem, not the report's.
- **Reconcile**: the header carries every rule's tally beside its rendered count — one
  entry per rule, a family hunter having returned one tally per rule it was given —
  `Hunters: R1 8/8 · R9 53/53 (not reached: internal/store) · R4–R6 skipped` — and the
  two agree, or the dropped finding is rendered, never the tally adjusted. Any agent's
  `not reached:` line renders verbatim beside its tally — a hunter's beside the tallies
  of the rules it hunted — and the Scope line then reads
  `Mode: FULL · PARTIAL coverage`; without those words the header asserts full
  coverage. A hunter's `R<N>: rule unreadable at <path>` line is the same: it renders
  verbatim in that rule's place in the header — never as `skipped`, never as a clean
  tally, never dropped — and the Scope line reads `PARTIAL coverage`; a rule that had
  hits and was not hunted is coverage the review did not have.
- Fix routing cites each rule's **Fix pattern**; out-of-scope observations go under
  BROADER CONTEXT; the report ends `Caller decides: commit as-is · fix 🔴 first · fix
  all. Findings are advisory.` **The report is the message** that ends the review —
  never a file, never a summary pointing at one, whatever its length.
</step_4_merged_report>

</protocol>

<modes>
**FULL:** the detection pass over the whole scope, all twelve rules; report every
surviving finding. **INCREMENTAL:** scope = the files changed since the last review;
run steps 1–3 on it and report the delta against the previous findings — ✅ Fixed (its
question's row in the new counts table is clear, or the hunter's re-judgment confirms),
⚠️ Remaining, 🆕 New.
</modes>

<constraints>
This skill MUST NOT:
- Edit code, fix findings, or invoke fix skills (@refactoring, @code-designing, @testing)
- Write the report, or any part of it, to a file — the bundle is the only file it
  writes, and an empty scope writes none
- Run the linter or tests, or block a commit — every finding is advisory
- Restate or paste rule content — spawn prompts name rules by absolute path and range
- Compose a detection command or a bundle recipe in place of `ldd-scope.sh` and
  `ldd-detect.sh` — the scripts are the pre-filter and the bundle
- Spawn anything but the three agents in `<objective>`, or wait for one by polling,
  monitoring, scheduling or re-spawning
</constraints>

<who_invokes>
@linter-driven-development (Phase 4, per completed slice) · @refactoring (after fixes,
INCREMENTAL) · the user (standalone review before commit).
</who_invokes>
