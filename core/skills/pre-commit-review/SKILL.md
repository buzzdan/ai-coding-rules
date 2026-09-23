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
critic — the agents `{{.Plugin}}:rule-hunter`, `{{.Plugin}}:overabstraction-skeptic` and
`{{.Plugin}}:comment-critic`, spawned by those names and no others. Pure orchestration
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
- **Diff scope**: the caller's resolved file list or diff range — an explicit argument,
  else the working tree's changes against `HEAD` (`git diff --name-only HEAD --
  '{{.SrcGlob}}'` plus untracked files), else the branch against its base, and the whole
  repository only when asked for explicitly. Never widened here; an empty scope is
  reported as "nothing to review", never as a clean verdict.
- **Mode**: `FULL` (first run) or `INCREMENTAL` (re-run after fixes; needs the previous
  report's findings).
</inputs>

<protocol>

<step_1_grep_prefilter>
In-context, cheap, no agents yet. One Bash command prints the **Falsifying questions**
section of every rule file, and this skill's hunt-focus table beside it —
`for f in <rules dir>/R*.md; do echo "==> $f <=="; sed -n '/^## Falsifying questions/,$p' "$f"; done; sed -n '/^## Hunt focus/,/^## Waiting for agents/p' <this skill dir>/reference.md`
— that section only, never a whole rule and never twelve Read calls; then run the
detection commands there against the diff scope (changed files only). The commands
live in the rule files (`../../rules/R1-…` to `R12-….md`); never restate them. A rule
with zero hits is skipped — no hunter for it.

{{include "skills/pre-commit-review/nolint-finding.md"}}

Also in-context — the **when-in-Rome check**: anything the diff introduces that the
repo does not already use (a new test mechanism, a dependency in `{{.ProjectMarker}}`,
a tool or config file, a convention-file edit bundled into a feature diff, a layout
unlike its siblings) is a 🟠 finding when a grep of the repo *outside* the diff shows
zero prior use; the fix is a discussion or a separate PR, never silent inclusion.
</step_1_grep_prefilter>

<step_2_spawn_hunters>
**Write the scope bundle first**, only when the scope is not empty, in one Bash
command into `B=$(mktemp -d)`:

- `files.txt` — the scope, one path per line. A file left out of `scope/` keeps its
  line with the reason: `(not bundled: deleted)`, `(not bundled: binary)` (`grep -Il .
  -- "$f"` prints nothing), `(not bundled: <n> lines)` over about 2000, `(not bundled:
  generated)` by the repository's markers. Hunters read those as ground their commands
  cover and nothing reads whole. Nothing else is filtered.
- `diff.patch` — on a scoped review, `git diff <range> -- '{{.SrcGlob}}'`; untracked
  files have no diff and appear only under `scope/`; `--all` has no diff.
- `scope/<path>.txt` — one per bundled file, at its source path, a `==> <path> <==`
  header then the text with its own line numbers, so a finding read from the bundle
  anchors like a `grep -n` hit:
  `while IFS= read -r f; do mkdir -p "$B/scope/$(dirname "$f")"; { printf '==> %s <==\n' "$f"; cat -n -- "$f"; } > "$B/scope/$f.txt"; done < bundled.txt`
- `dirs.txt` — on `--all`, the source directories with file and line counts, for the
  hunters' reading orders.

The same Bash call prints `sed -n '/^## Waiting for agents/,/^## The merged report/p'
<this skill dir>/reference.md` — how agents are waited for, what each returns and what
their verdicts do — so steps 2, 3 and 3b cost no read of their own. The bundle is the
only file this review writes; hunters and the critic get its path, the skeptic does
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

A family none of whose rules had a hit gets no hunter. Each spawn prompt MUST contain:

1. **The absolute paths of this family's rule files with hits** — the hunter's whole
   rulebook, each read whole in its first turn. Never the text pasted; never a rule of
   the family that had no hit; never two families in one hunter; the parent reads no
   rule to build a prompt (step 1 printed only the questions).
2. **The bundle's absolute path** and the diff scope it holds. On `--all`, also this
   hunter's **reading order**: `dirs.txt` with the family's combined pre-filter hits
   first, most hits first, ties by line count ascending, then the rest — no two
   hunters truncate at the same tail.
3. **The family's pre-filter hits, per rule**, as starting leads, never a limit.

Every path is absolute (the hunter runs in the reviewed project's cwd): resolve
`../../rules/R<N>-….md` and any case file the rule cites from this skill's own
location, then `ls` every resolved path before spawning — listing is not reading; a
path that does not list is fixed here, never handed to a hunter. Each hunter returns
finding blocks (`rule | file:line | evidence | fix pattern | effort`), one receipt per
falsifying question of each rule it was given (`R<N> Q<n>: <hits> hit(s) → <findings>
finding(s)`), one tally per rule — or, for a rule file that did not read, `R<N>: rule
unreadable at <path>` in the tally's place — and, when its budget ended the hunt, one
`not reached:` line — receipts stay whole because the detection commands ran over the
whole scope. A question with no receipt was not run. Findings, receipts, tallies (or
unreadable lines) and that line are the whole report, about 3k tokens; a hunter returns
no narrative ("Hunter output", read above).
</step_2_spawn_hunters>

<step_3_skeptic_pass>
Collect every type/package-extraction finding — R1/R2/R4 "create a type/package", R10
"Extract Synchronized Owner", R11 "Interface Dispatch" / "Strategy Map" — and spawn one
overabstraction-skeptic, foreground, in a message with no hunters in it, after every
hunter result is in hand; the critic (step 3b) shares that message. Its spawn prompt
MUST contain:

1. The extraction findings under review — the hunter blocks pasted verbatim.
2. The absolute path of `../../rules/R1-primitive-obsession.md` and the range it reads:
   `sed -n '/^### Juiciness scoring/,/^### Placement/p'`. Never the file whole.
3. The absolute path of `../../examples/overabstraction-cidr.md`; with R11 dispatch
   proposals under review, also `../../examples/anti-if-dispatch.md` and
   `../../examples/switch-to-polymorphism.md`.

No bundle: the skeptic verifies call sites across the whole repository. Its verdicts
(`CONFIRMED (score N …)`, `CONFIRMED (score N, judgment call) — alternative: …`,
`REFUTED (score N …) → cheaper alternative`, `N/A (R2 mechanism)`, `skeptic: not
reached`) are carried into the report verbatim, score included. What never goes to it
(R2's construction mechanics, non-extraction findings) and what each verdict does:
"Skeptic verdicts", read in step 2.
</step_3_skeptic_pass>

<step_3b_comment_critic>
When the diff contains comment lines — prefilter:
{{include "skills/pre-commit-review/critic-prefilter.md"}}
(any hit qualifies; directives don't count) — spawn one comment-critic in the same
hunter-free message as the skeptic (alone when no skeptic runs), foreground; its sweep
is the longest pass of the review and is waited for only by the call returning. Its
spawn prompt MUST contain:

1. The absolute path of `../../rules/R9-repo-brain.md` and the range of its **Comment
   policy** section: `sed -n '/^### Comment policy/,/^### Edge conventions/p'`.
2. The absolute path of `../documentation/reference.md` and the range of its **Comment
   Value Toolbox** catalog:
   `sed -n '/^## Comment Value Toolbox/,/^## Frontmatter Templates/p'`.
   Neither file is read whole.
3. The absolute path of `../../examples/private-comment-noise.md`.
4. The diff scope and the bundle's absolute path — when this review wrote one; a caller
   without a bundle omits it, and the critic builds its scope in its first turn.

It returns per-comment verdicts (`KEEP / TRIM / REWRITE / DELETE`, `DELETE → route
R3`) with evidence and replacement text, and a tally; non-KEEP verdicts are 🟡
Readability Debt ("Critic verdicts", read in step 2).
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
  {{.Nil}} handed to the constructor are three R2 questions on one type, one missing
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
- **Categories**: 🐛 Bugs · 🟠 New Practice · 🔴 Design Debt · 🟡 Readability Debt (R3,
  R9, the critic's non-KEEP verdicts) · 🟢 Polish (the skeptic's cheaper alternatives).
- **One line per finding**: `file:line | R<N> Q<n>: evidence in the question's own
  words | the move as the rule's Fix pattern spells it | S/M/L`. The fix cell names the
  move exactly as the Fix pattern section spells it — `Introduce Parameter Object`,
  `Name enum strings`, `Extract Leaf Type` — and the skeptic's verdict and score follow
  the move in the same cell: `Introduce Parameter Object: Endpoint — skeptic REFUTED
  (score 1) → rename dial to Client.dial`. A verdict never replaces the move name with
  its alternative; a refuted type's alternative also ships as its own 🟢 Polish line. A
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
**FULL:** pre-filter all twelve rules over the whole scope; report every surviving
finding. **INCREMENTAL:** scope = the files changed since the last review; run steps
1–3 on it and report the delta against the previous findings — ✅ Fixed (its detection
command re-run confirms), ⚠️ Remaining, 🆕 New.
</modes>

<constraints>
This skill MUST NOT:
- Edit code, fix findings, or invoke fix skills (@refactoring, @code-designing, @testing)
- Write the report, or any part of it, to a file — the bundle is the only file it
  writes, and an empty scope writes none
- Run the linter or tests, or block a commit — every finding is advisory
- Restate or paste rule content — spawn prompts name rules by absolute path and range
- Spawn anything but the three agents in `<objective>`, or wait for one by polling,
  monitoring, scheduling or re-spawning
</constraints>

<who_invokes>
@linter-driven-development (Phase 4, per completed slice) · @refactoring (after fixes,
INCREMENTAL) · the user (standalone review before commit).
</who_invokes>
