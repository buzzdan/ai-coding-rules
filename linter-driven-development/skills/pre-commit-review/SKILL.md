---
name: pre-commit-review
description: |
  ADVISORY pre-commit review that orchestrates parallel single-obsession rule hunters, an over-abstraction skeptic, and a comment critic against the diff.
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
parallel single-obsession `linter-driven-development:rule-hunter` agents, one `linter-driven-development:overabstraction-skeptic`, and one
`linter-driven-development:comment-critic`.
Pure orchestration and reporting: this skill may spawn agents but never edits code, never
fixes findings, and never blocks a commit. Rule knowledge lives once in `../../rules/`;
agents receive it as spawn-time payload — they do not invoke skills.
</objective>

<timing>
Run pre-commit, per completed vertical slice — NEVER mid-implementation. GREEN-step TDD
code is supposed to look under-designed; reviewing it produces false positives. The
per-cycle detection greps in the REFACTOR step (see @refactoring) are the
mid-implementation net; this pass is the verification net on finished work.
</timing>

<inputs>
- **Diff scope**: the caller's resolved file list or diff range. Callers resolve it by one
  ladder — an explicit argument, else the working tree's changes against `HEAD`
  (`git diff --name-only HEAD -- 'detected-language source'` plus untracked files), else the current
  branch against its base, and the whole repository only when asked for explicitly. This
  skill never widens the scope it is given, and an empty scope is reported as "nothing to
  review" — never as a clean verdict.
- **Mode**: `FULL` (first run) or `INCREMENTAL` (re-run after fixes — requires the
  previous report's findings).
</inputs>

<protocol>

<step_1_grep_prefilter>
In-context, cheap — no agents yet. For each rule below, read its rule file's
**Falsifying questions** section and run the detection commands there against the diff
scope (changed files only). The commands live in the rule files; never restate them here.
A rule with zero hits is skipped — no hunter spawned for it.

| Rule | File | Hunt focus |
|------|------|------------|
| R1 | `../../rules/R1-primitive-obsession.md` | domain concepts as raw primitives; sentinel returns; ceremony wrappers (inverse) |
| R2 | `../../rules/R2-self-validating-types.md` | invalid-state construction; defensive re-checks; the missing value returned where a real value is expected |
| R3 | `../../rules/R3-storifying.md` | mixed abstraction levels; comments naming unextracted blocks |
| R4 | `../../rules/R4-helper-placement.md` | helper visibility/placement off the placement ladder |
| R5 | `../../rules/R5-vertical-slice.md` | horizontal layering; role-named packages |
| R6 | `../../rules/R6-test-only-interfaces.md` | interfaces whose only second implementer is a test double |
| R7 | `../../rules/R7-test-placement.md` | tests reaching privates; success-or-error flag conditionals; wrong-rung tests; sleeps |
| R8 | `../../rules/R8-no-globals.md` | package-level state; library code manufacturing its own root cancellation |
| R9 | `../../rules/R9-repo-brain.md` | orphan docs; broken doc edges (both directions); WHAT-comments on exported API; unwired root; bundle-contract breaks (missing frontmatter, index timestamps, log.md) |
| R10 | `../../rules/R10-concurrency-safety.md` | concurrent tasks without exit paths or owners; unguarded shared-state writes; production sleeps; decorative mutexes |
| R11 | `../../rules/R11-conditional-dispatch.md` | one discriminator switched in ≥2 places; type switches in domain logic; unknown-kind defaults away from the boundary; flag arguments; unearned dispatch abstractions (inverse) |
| R12 | `../../rules/R12-mutation-discipline.md` | internal slices/maps returned by reference; constructors aliasing caller collections; query/modifier hybrids; setters around validating constructors; ceremony copies (inverse) |

Also in-context: a new suppression directive in the diff — the language's form of
`# noqa`, `# type: ignore`, `eslint-disable`, `#[allow(...)]`, `@SuppressWarnings`,
or whatever the repository's linter documents — or a new exclusion in the linter's
configuration file is itself a finding — the change must justify, with evidence,
that the rule genuinely does not apply.

Also in-context — the **when-in-Rome check**: a diff must arrive in the host repo's
existing style, not import a new one. Flag anything the diff introduces that the repo
does not already use: a new test mechanism (golden files, snapshot testing, a new
assertion library), a new dependency in `the language's project manifest`, a new tool or config file, edits to
repo-level convention files (CLAUDE.md, coding standards, lint config) bundled into a
feature diff, or a directory layout unlike its siblings. Detection is comparative:
for each candidate, grep the repo *outside* the diff for prior use — zero prior use
is the finding. These are not style crimes; they are adoption decisions that belong
to the repo owner. The fix is a discussion or a separate PR, never silent inclusion.
</step_1_grep_prefilter>

<step_2_spawn_hunters>
For every rule with pre-filter hits, spawn one `linter-driven-development:rule-hunter` agent, as **foreground**
`Agent` calls (`run_in_background: false`) issued together in one message, so the hunters
run in parallel and every result comes back in that same message. A foreground call
blocks until its hunter returns — a whole-repository hunter takes one to four minutes —
and the review never waits for one any other way: no `ReadNotifications`, `ListAgents`
or `Monitor` calls, no scheduled wake-up. One host differs: a Claude Code cloud session
(`CLAUDE_AUTO_BACKGROUND_TASKS` set) turns a foreground call still running after 120
seconds into a background task and answers "Async agent launched". That hunter is still
running and its result arrives by itself when it finishes; do not poll for it and do not
spawn it again — work through the results in hand, and when nothing is left but waiting,
end the message and let the delivery resume the review. The skeptic and the critic
(step 3) share one message of their own, spawned only once every hunter result is in
hand. Each spawn prompt MUST contain:

1. **The rule file's FULL content, pasted** — the hunter's entire rulebook and single
   obsession. Never a path reference alone; never more than one rule per hunter.
2. **The diff scope** — the changed-file list or `git diff` range.
3. **That rule's pre-filter hits** — as starting leads (the hunter re-runs the
   detection commands itself; leads are a starting point, not a limit).

If the rule cites a case file by plugin-relative path (e.g. `../examples/*.md`), resolve
it to an absolute path and include that path in the spawn prompt — the hunter runs in the
reviewed project's cwd and cannot resolve plugin-relative paths on its own.

Each hunter returns one block per finding:
`rule | file:line | evidence (falsifying-question answers) | proposed fix pattern | effort (S/M/L)`
plus one receipt line per falsifying question (`Q<n>: <hits> hit(s) → <findings>
finding(s)`) and a final tally line (`R<N>: <M> finding(s)` or a hunted-clean line).
The receipts are how a whole-repository hunt is read: a question with no receipt was
not run over the scope, and the leads were never the scope.
</step_2_spawn_hunters>

<step_3_skeptic_pass>
Collect ALL type/package-extraction findings — every R1/R2/R4 "create a type/package"
proposal, R10 "Extract Synchronized Owner" proposals, and R11 "Interface Dispatch" /
"Strategy Map" proposals — and spawn one `linter-driven-development:overabstraction-skeptic`, as a **foreground**
`Agent` call (`run_in_background: false`) in a message with no hunters in it, after
every hunter result is in hand; the comment critic (step 3b), when it runs, is spawned
in that same message so the two run in parallel. Its spawn prompt MUST contain:

1. The extraction findings under review — the hunter blocks pasted verbatim.
2. Payload: the **Juiciness scoring** and **The over-abstraction trap** sections of
   `../../rules/R1-primitive-obsession.md`, pasted.
3. Payload: the FULL content of `../../examples/overabstraction-cidr.md`, pasted.

Verdicts per finding: `CONFIRMED (score ≥4 + verified evidence)`, `CONFIRMED (score
2–3, judgment call) — alternative: …` (the type ships as the finding's fix with the
skeptic's cheaper move beside it; the user chooses), or `REFUTED (score 0–1 + reason) →
cheaper alternative`. Carry the verdict word and the score into the report verbatim, as
the report example shows. A refuted proposal does not ship; when its cheaper
alternative (better naming, private fields + accessors, or R11's Keep the Single
Exhaustive Switch) is still worth doing, report the alternative as 🟢 Polish. When R11
dispatch proposals are under review, additionally paste the FULL
content of both R11 case files — `../../examples/anti-if-dispatch.md` (Move 3 is the
juiciness rejection: the switch stays, goes exhaustive) and
`../../examples/switch-to-polymorphism.md` (the dependency-direction rejection: the
move is unavailable when the consumer owns the output format; the switch shrinks to
pure dispatch). Only findings the skeptic cannot kill ship as extraction
findings. Non-extraction findings (R3, R5–R9, and R1/R2/R10/R11 findings that propose
no new type) skip the skeptic and go straight to the report — R9 findings (orphans,
broken edges, WHAT-comments, unwired root) propose no type extractions. R2's
construction mechanics — a validating constructor, internal fields, an options
type with its `With*` functions, a named Null Object default — are not extractions either
and never go to the skeptic: they close the holes of a type that already exists, and a
skeptic verdict on them would be scoring a guard, not a type.
</step_3_skeptic_pass>

<step_3b_comment_critic>
When the diff contains comment lines — prefilter:
`git diff --cached -- 'detected-language source'` filtered to added lines that carry the
language's comment marker (`//`, `#`, `/*`, `--`, a docstring opener), minus
directive lines — compiler pragmas, build tags, the linter's suppression
directive, doc-test output markers
(any hit qualifies; directives don't count) — spawn one `linter-driven-development:comment-critic` in the same
hunter-free message as the skeptic (when no skeptic runs, the critic has that message
alone), also in the **foreground** (`run_in_background: false`): its full-repository
comment sweep is the longest pass of the review, and waiting for it is done by the
foreground call returning — or, in a cloud session that backgrounds it after 120
seconds, by its result arriving on its own — never by a timer, a scheduled wake-up or
a notification poll. Its spawn prompt MUST contain:

1. Payload: R9's **Comment policy** section (`../../rules/R9-repo-brain.md`,
   Design guidance) pasted verbatim — the Comment Value Toolbox kinds, the
   three-test standard, the tier table, budget accounting, and the visibility
   default.
2. Payload: the **Comment Value Toolbox** catalog section of
   `../documentation/reference.md` (resolve to an absolute path) pasted verbatim.
3. The absolute path to `../../examples/private-comment-noise.md` — the critic
   reads it when judging comments on internal symbols.
4. The diff scope.

It judges every comment in the diff (doc comment, in-body, test) against the three-test
standard and returns per-comment verdicts (`KEEP / TRIM / REWRITE / DELETE`, or
`DELETE → route R3` for in-body extraction candidates) with evidence and proposed
replacement text. Non-KEEP verdicts land in the report as 🟡 Readability Debt;
`DELETE → route R3` verdicts merge with any R3 hunter findings on the same lines
(one finding, not two). The critic is advisory like everything else — accepted
verdicts are fixed by @documentation (the rung-1 fixer), except R3 routes, which
go to @refactoring.
</step_3b_comment_critic>

<step_4_merged_report>
Merge surviving findings into one report.

**Cluster pass (before categorizing):** group *every* hunter finding — kept, refuted
by the skeptic, or never sent to it — by shared anchor. An anchor is the named thing a
finding is about, never its line: a type (a finding on one of its fields and a finding
on one of its methods share the type), a function, a discriminator, or a package (two
findings on files of one package share the package, and findings that name the same
two packages together share both as one anchor). List the anchors first, then count.
An anchor converges when ≥2 findings from *different* rules land on it, or ≥2
findings answering *different* falsifying questions of one rule — exported nilable
fields, a method that re-checks them and a null handed to the constructor are three
questions of R2 answered on one type, and one missing constructor, not three lines.
Two findings of the same question on one anchor are a shared-shape line below, not a
cluster. The skeptic's verdict removes a proposed type from the fix column; it never
removes the convergence, which is the evidence. Each hunter is single-obsession and
blind to the others, and each falsifying question is blind to the next, so independent
convergence on one anchor is evidence that a domain concept is missing there — the
cluster is a juiciness scorecard that filled itself in (R1 hunter sees the raw
primitive, R11 the duplicated switch, R2 the ownerless validation: one disease, four
jurisdictions). Render each cluster as a first-class entry above the categories:

```
🔗 CLUSTER: Alert.Channel
   Convergence: 4 findings — R1, R11, R2, R7
   Hypothesis: missing domain concept — a Channel type wants to exist
   Skeptic: CONFIRMED (score 6: switched in 3 files, +2 unrepresentable — the
   unknown-channel default at notify.<ext>:71 goes; +2 noun — Send/Deliver)
   Routing: design-first — @code-designing (cluster-scoped), then @refactoring
   implements; do NOT fix members independently (partial fixes undo each other)
```

Render *every* cluster the pass finds, one `🔗 CLUSTER: <anchor>` line per converged
anchor: two findings or twenty, the largest and the smallest alike. The title is the
anchor itself — the type, field, function or package name the findings share
(`🔗 CLUSTER: ProcessHeartbeat`, `🔗 CLUSTER: Catalog.Find`,
`🔗 CLUSTER: internal/common, internal/utils`), never a description of the problem;
the description is the Hypothesis line beneath it. When the skeptic
reviewed an extraction at that anchor, the entry carries its verdict — a CONFIRMED
type routes design-first as above; a REFUTED one keeps the cluster (the convergence
is still real) and routes to the cheaper alternative, which ships as 🟢 Polish. When no
extraction was proposed at the anchor (a function three rules converged on, say) the
entry carries no verdict and routes to @refactoring. The example shows one cluster; a
whole-repository review commonly has six or more, and the pass is not done until each
anchor that two rules converged on has its own entry. Member findings still appear
under their categories below, each as its own line tagged `[cluster: <anchor>]`: the
cluster's Evidence line is an index, and a member that appears only there — a
production sleep named in the cluster's prose and nowhere under 🔴 — is a finding the
report dropped. Each member sits under the rule whose falsifying question its evidence
answers, never under the cluster's lead rule: the sentinel `0` a config reader returns
is R2's question even when R1 owns the cluster. Clustering is *reporting*
— this skill still never edits and never invokes fix skills; the caller routes.

Category mapping:

- 🐛 **Bugs** — will fail at runtime regardless of rule (null returned as a value,
  cancellation severed by a manufactured root context, R10 concurrent task leaks and
  unguarded concurrent writes): fix immediately.
- 🟠 **New Practice (when in Rome)** — the when-in-Rome check's findings: a
  mechanism, dependency, framework, or convention the host repo does not already
  use, introduced without discussion. Advisory like everything else, but flag it
  loudly: reviewers reject these threads hardest, and the fix (owner buy-in or a
  separate PR) is cheap before pushing and expensive after.
- 🔴 **Design Debt** — R1, R2, R4, R6, R7, R8, R10's non-crash findings (production
  sleeps, fire-and-forget ownership, mutex placement), R11 (duplicated discriminators,
  boundary leaks), R12 (leaked mutable internals, unvalidated setters), and R5
  (advisory — never blocks; the user may have valid reasons): fix before commit
  recommended.
- 🟡 **Readability Debt** — R3, R9, unclear naming, and the comment-critic's
  non-KEEP verdicts (trash or over-budget or hard-to-read comments): improves
  maintainability.
- 🟢 **Polish** — minor idiomatic improvements, the skeptic's cheaper alternatives.

**One line per finding, anchored and answered.** Every finding a hunter returned and
the skeptic did not kill, every cheaper alternative the skeptic shipped in a refuted
type's place, and every non-KEEP verdict the comment critic returned renders as its
own line in the hunter's shape, `file:line | evidence | fix | effort` (a critic line's
evidence is its verdict and reason, its fix the REWRITE text or DELETE, and its effort
S — a comment edit is always small; a `DELETE → route R3` verdict merges into the R3
finding on those lines and takes that finding's effort), as the report example shows:

- The line opens with the `file:line` anchor the hunter cited. A finding without its
  anchor is a claim, not a finding.
- The evidence cell names the rule and the falsifying question the finding answers,
  by number and in the question's own words — `R1 Q5: host, port and tls travel
  together across three signatures` — so the reader can open the rule and check.
  When the question asks about text in the code — a block comment, a docstring, a
  suppression directive — the cell quotes that text, not its line number alone:
  `R3 Q3: three section comments name unextracted blocks — "# parse the line" (101),
  "# look up or create device" (129), "# transitions" (149)`. The quoted comment is
  the evidence and the name of the function to extract.
- The fix cell names the move exactly as the rule's **Fix pattern** section spells it
  (`Introduce Parameter Object`, `Name enum strings`, `Extract Leaf Type`,
  `Introduce Null Object`); a paraphrase of the move belongs in the evidence, never in
  its place. The skeptic's verdict and score follow the move when one applies.
- Effort carries over from the hunter (S/M/L).

A count is never a finding. `R9 (46 findings)` or `R1 (8 findings): highlights …`
drops the anchors a reader needs to act on and is forbidden as a rendering, whatever
the scope. The unit that must never be lost is the anchor: every finding's `file:line`
appears in the report, heading its own line, or — when several findings share one
shape (thirty restating comments, say) — listed on one shared-shape line that names
every anchor and the shared evidence and fix once. Either way the anchors rendered
equal the findings returned. Length is never a reason to roll up: a whole-repository
review with a hundred and thirty findings renders a hundred and thirty anchors,
grouped under their categories and rules.

**Reconcile before emitting.** Every hunter ends with a tally (`R<N>: <M> finding(s)`).
The report header carries, per hunter, that tally beside the number of its anchors
rendered below (own line or shared-shape line alike) —
`Hunters: R1 8/8 · R7 7/7 · R9 53/53 · R4–R6 skipped` — and the two numbers agree for
every rule before the report is emitted; a rendered count below the tally means a
finding was dropped in the merge, and the fix is to render it, never to adjust the
tally. A finding the skeptic refuted still counts as rendered when its
cheaper alternative is on the page.
Fix routing is each rule file's **Fix pattern** section; cite it, don't restate it.
Issues noticed outside the diff scope go in a BROADER CONTEXT section, not as findings.

**The report is the message.** The report is emitted as the text of the message that
ends the review — never written to a file, never attached, never replaced by a summary
that points at a file or at "the report I sent". Length is no reason: a
whole-repository report of thirty kilobytes is the normal size and goes in the message
whole, under its categories. This skill has nothing to write to disk; a Write call
during a review is the report leaving the page.
</step_4_merged_report>

</protocol>

<modes>
**FULL (first run):** pre-filter all twelve rules over the whole diff scope; report every
surviving finding.

**INCREMENTAL (re-run after fixes):** diff scope = only files changed since the last
review. Run steps 1–3 on that scope, compare against the previous findings, and report a
delta: ✅ **Fixed** (previous finding no longer reproducible — re-run its detection
command to confirm), ⚠️ **Remaining** (still evidenced), 🆕 **New** (introduced by the
fixes). Use after @refactoring applies fixes or whenever the caller iterates.
</modes>

<report_example>
```
📊 CODE REVIEW REPORT
Scope: user/service.<ext>, user/auth.<ext> (+ tests) · Mode: FULL
Hunters: R1 2/2 · R2 1/1 · R3 1/1 (findings returned/rendered) · R4–R8 skipped
Skeptic: 1 extraction CONFIRMED, 1 REFUTED (score 1 → rename instead)
Critic: 14 comments reviewed — 11 KEEP · 2 REWRITE · 1 DELETE

🔴 DESIGN DEBT                       (one finding per line; wrapped here for width)
user/service.<ext>:67 | R1 Q1: the session token is validated inline as a raw string,
  no ParseX owns it; Q2: the same emptiness predicate at user/auth.<ext>:41 — two
  owners | Replace Primitive with Domain Type: SessionToken — skeptic CONFIRMED
  (score 5) | M
user/auth.<ext>:34 | R2 Q1: Authenticator.HashCost is exported, so a literal builds an
  invalid Authenticator; Q2: Verify re-checks the range at auth.<ext>:52 | Add
  validating constructor: NewAuthenticator | S

🟡 READABILITY DEBT
user/auth.<ext>:89 | R3 Q2: Authenticate mixes the auth flow with bcrypt byte handling
  in one body; Q3: the block comment `<comment-marker> compare password` names the section |
  Extract Function named after the comment: comparePassword | S
user/service.<ext>:15 | critic: the doc comment restates the name ("UserService provides
  user services") — toolbox-value floor, no toolbox item delivered | REWRITE →
  wider context: "Every user mutation flows through this service — auth, quota,
  and audit hooks attach here." | S

🟢 POLISH
user/auth.<ext>:12 | ComparePasswordWithHash → PasswordMatches — skeptic's cheaper
  alternative to REFUTED PasswordHash wrapper (score 1: only method unwraps) | S

📝 BROADER CONTEXT
user/service.<ext>:23 — email still a raw string (outside diff scope; same R1 pattern).

Caller decides: commit as-is · fix 🔴 first · fix all. Findings are advisory.
```
</report_example>

<constraints>
This skill MUST NOT:
- Edit code, fix findings, or invoke fix skills (@refactoring, @code-designing, @testing)
- Write the report, or any part of it, to a file — the report is the message that
  ends the review, whole, whatever its length
- Run the linter or tests — the caller does (see @linter-driven-development)
- Block commits — every finding is advisory; the caller decides what to fix
- Restate rule content — rules live once in `../../rules/`; paste them as spawn payload
  and cite them in findings
- Spawn anything other than `linter-driven-development:rule-hunter`, `linter-driven-development:overabstraction-skeptic`, and
  `linter-driven-development:comment-critic`
- Wait for any agent by polling notifications, arming a monitor or scheduling a
  wake-up, or spawn an agent a second time because its call was answered "Async agent
  launched"; a foreground call returns its result in the same message, and a call a
  cloud session backgrounded after 120 seconds delivers its result by itself
</constraints>

<who_invokes>
1. **@linter-driven-development** — Phase 4, pre-commit / per completed vertical slice
2. **@refactoring** — after applying patterns, to validate design quality (INCREMENTAL)
3. **User** — manual standalone review before commit
</who_invokes>
