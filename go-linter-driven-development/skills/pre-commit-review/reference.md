# Pre-Commit Review — Reference

`SKILL.md` holds the protocol; this file holds the long form each step reads by `sed`
range at the moment it needs it, never the file whole and never before that step. The
sections, in the order the steps use them: Hunt focus · Waiting for agents · Hunter
output · Skeptic verdicts · Critic verdicts · The merged report · Report example. The
first five are printed by the Bash calls steps 1 and 2 already make, so they cost no
round trip; the last two are read once, before the report is written.

## Hunt focus

What each hunter is after — the pre-filter's map of the rules. Four hunters, one per
family with hits, each given the rows of its family that had hits: **types** (R1, R2,
R11, R12), **structure** (R3, R4, R5), **tests and dependencies** (R6, R7, R8, R10)
and **documentation** (R9, beside the comment critic):

| Rule | Family | File | Hunt focus |
|------|--------|------|------------|
| R1 | types | `../../rules/R1-primitive-obsession.md` | domain concepts as raw primitives; sentinel returns; ceremony wrappers (inverse) |
| R2 | types | `../../rules/R2-self-validating-types.md` | invalid-state construction; defensive re-checks; the missing value returned where a real value is expected |
| R3 | structure | `../../rules/R3-storifying.md` | mixed abstraction levels; comments naming unextracted blocks |
| R4 | structure | `../../rules/R4-helper-placement.md` | helper visibility/placement off the placement ladder |
| R5 | structure | `../../rules/R5-vertical-slice.md` | horizontal layering; role-named packages |
| R6 | tests and dependencies | `../../rules/R6-test-only-interfaces.md` | interfaces whose only second implementer is a test double |
| R7 | tests and dependencies | `../../rules/R7-test-placement.md` | tests reaching privates; success-or-error flag conditionals; wrong-rung tests; sleeps |
| R8 | tests and dependencies | `../../rules/R8-no-globals.md` | package-level state; library code manufacturing its own root cancellation |
| R9 | documentation | `../../rules/R9-repo-brain.md` | orphan docs; broken doc edges (both directions); WHAT-comments on exported API; unwired root; bundle-contract breaks (missing frontmatter, index timestamps, log.md) |
| R10 | tests and dependencies | `../../rules/R10-concurrency-safety.md` | goroutines without exit paths or owners; unguarded shared-state writes; production sleeps; decorative mutexes |
| R11 | types | `../../rules/R11-conditional-dispatch.md` | one discriminator switched in ≥2 places; type switches in domain logic; unknown-kind defaults away from the boundary; flag arguments; unearned dispatch abstractions (inverse) |
| R12 | types | `../../rules/R12-mutation-discipline.md` | internal slices/maps returned by reference; constructors aliasing caller collections; query/modifier hybrids; setters around validating constructors; ceremony copies (inverse) |

## Waiting for agents

For every rule family with pre-filter hits, spawn one `go-linter-driven-development:rule-hunter` agent —
four at most — as **foreground** `Agent` calls (`run_in_background: false`) issued
together in one message, so the hunters run in parallel and every result comes back in
that same message. A foreground call
blocks until its hunter returns — a whole-repository hunter takes one to four minutes —
and the review never waits for one any other way: no `ReadNotifications`, `ListAgents`
or `Monitor` calls, no scheduled wake-up. One host differs: a Claude Code cloud session
(`CLAUDE_AUTO_BACKGROUND_TASKS` set) turns a foreground call still running after 120
seconds into a background task and answers "Async agent launched". That hunter is still
running and its result arrives by itself when it finishes; do not poll for it and do not
spawn it again — work through the results in hand, and when nothing is left but waiting,
end the message and let the delivery resume the review. The skeptic and the critic
(step 3) share one message of their own, spawned only once every hunter result is in
hand.

## Hunter output

Each hunter returns one block per finding:
`rule | file:line | evidence (falsifying-question answers) | proposed fix pattern | effort (S/M/L)`
plus one receipt line per falsifying question of each rule it was given (`R<N> Q<n>:
<hits> hit(s) → <findings> finding(s)`, in rule order) and one tally line per rule
(`R<N>: <M> finding(s)` or that rule's hunted-clean line) — a types hunter given R1, R2
and R11 returns three tallies. The receipts are how a whole-repository hunt is read: a
question with no receipt was not run over the scope, and the leads were never the
scope. A hunter that spends the tool-call budget its agent definition states returns
the same shape plus one `not reached: …` line for the hunter, naming the files or
directories it did not read to judge — its detection commands still ran over the whole
scope, so its receipts are whole — and the report header renders that line verbatim
beside the tallies of the rules it hunted (step 4), never as a clean verdict.

**The report cap.** A hunter's report is its finding blocks, its receipts, its tallies
and its `not reached:` line — nothing else: no narrative of the hunt, no restating of
a rule, no code beyond the evidence excerpt inside a finding block. About 3k tokens.
The parent merges four of these into one report and keeps only those four things, so
every other word a hunter writes is billed and dropped.

## Skeptic verdicts

Verdicts per finding: `CONFIRMED (score ≥4 + verified evidence)`, `CONFIRMED (score
2–3, judgment call) — alternative: …` (the type ships as the finding's fix with the
skeptic's cheaper move beside it; the user chooses), or `REFUTED (score 0–1 + reason) →
cheaper alternative`. Carry the verdict word and the score into the report verbatim, as
the report example shows. A refuted proposal does not ship; when its cheaper
alternative (better naming, private fields + accessors, or R11's Keep the Single
Exhaustive Switch) is still worth doing, report the alternative as 🟢 Polish. When R11
dispatch proposals are under review, additionally include the absolute paths of both
R11 case files — `../../examples/anti-if-dispatch.md` (Move 3 is the
juiciness rejection: the switch stays, goes exhaustive) and
`../../examples/switch-to-polymorphism.md` (the dependency-direction rejection: the
move is unavailable when the consumer owns the output format; the switch shrinks to
pure dispatch). A finding the skeptic's budget did not reach carries
`skeptic: not reached` in the verdict's place and ships as the hunter proposed it.
Only findings the skeptic cannot kill ship as extraction findings. Non-extraction
findings (R3, R5–R9, and R1/R2/R10/R11 findings that propose no new type) skip the
skeptic and go straight to the report — R9 findings (orphans,
broken edges, WHAT-comments, unwired root) propose no type extractions. R2's
construction mechanics — a validating constructor, unexported fields, an options
type with its `With*` functions, a named Null Object default — are not extractions either
and never go to the skeptic: they close the holes of a type that already exists, and a
skeptic verdict on them would be scoring a guard, not a type.

## Critic verdicts

It judges every comment in the diff (godoc, in-body, test) against the three-test
standard and returns per-comment verdicts (`KEEP / TRIM / REWRITE / DELETE`, or
`DELETE → route R3` for in-body extraction candidates) with evidence and proposed
replacement text. Non-KEEP verdicts land in the report as 🟡 Readability Debt;
`DELETE → route R3` verdicts merge with any R3 hunter findings on the same lines
(one finding, not two). The critic is advisory like everything else — accepted
verdicts are fixed by @documentation (the rung-1 fixer), except R3 routes, which
go to @refactoring.

## The merged report

**Cluster pass (before categorizing):** group *every* hunter finding — kept, refuted
by the skeptic, or never sent to it — by shared anchor. An anchor is the named thing a
finding is about, never its line: a type (a finding on one of its fields and a finding
on one of its methods share the type), a function, a discriminator, or a package (two
findings on files of one package share the package, and findings that name the same
two packages together share both as one anchor). List the anchors first, then count.
An anchor converges when ≥2 findings from *different* rules land on it, or ≥2
findings answering *different* falsifying questions of one rule — exported nilable
fields, a method that re-checks them and a nil handed to the constructor are three
questions of R2 answered on one type, and one missing constructor, not three lines.
Two findings of the same question on one anchor are a shared-shape line below, not a
cluster. The skeptic's verdict removes a proposed type from the fix column; it never
removes the convergence, which is the evidence. Each hunter owns one rule family and
is blind to the other families, each rule inside a hunter is hunted by its own
detection commands, and each falsifying question is blind to the next, so independent
convergence on one anchor is evidence that a domain concept is missing there — the
cluster is a juiciness scorecard that filled itself in (R1's questions see the raw
primitive, R11's the duplicated switch, R2's the ownerless validation: one disease,
four jurisdictions). Render each cluster as a first-class entry above the categories:

```
🔗 CLUSTER: Alert.Channel
   Convergence: 4 findings — R1, R11, R2, R7
   Hypothesis: missing domain concept — a Channel type wants to exist
   Skeptic: CONFIRMED (score 6: switched in 3 files, +2 unrepresentable — the
   unknown-channel default at notify.go:71 goes; +2 noun — Send/Deliver)
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

- 🐛 **Bugs** — will fail at runtime regardless of rule (nil returned as a value,
  cancellation severed by a manufactured root context, R10 goroutine leaks and
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
finding on those lines and takes that finding's effort), as the report example below shows:

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

**Reconcile before emitting.** Every hunter ends with one tally per rule it was given
(`R<N>: <M> finding(s)`). The report header carries, per rule, that tally beside the
number of its anchors rendered below (own line or shared-shape line alike) —
`Hunters: R1 8/8 · R7 7/7 · R9 53/53 · R4–R6 skipped` — and the two numbers agree for
every rule before the report is emitted; a rendered count below the tally means a
finding was dropped in the merge, and the fix is to render it, never to adjust the
tally. A finding the skeptic refuted still counts as rendered when its
cheaper alternative is on the page. A hunter, the skeptic or the critic that returned
a `not reached:` line has it rendered verbatim in the header beside its tally — a
family hunter's beside the tallies of the rules it hunted —
`R9 12/12 (not reached: internal/store, internal/api)`, `Skeptic: 3 CONFIRMED · 1 not
reached` — and the Scope line then reads `Mode: FULL · PARTIAL coverage`. A header
without those words asserts that every agent covered the whole scope.
Fix routing is each rule file's **Fix pattern** section; cite it, don't restate it.
Issues noticed outside the diff scope go in a BROADER CONTEXT section, not as findings.

**The report is the message.** The report is emitted as the text of the message that
ends the review — never written to a file, never attached, never replaced by a summary
that points at a file or at "the report I sent". Length is no reason: a
whole-repository report of thirty kilobytes is the normal size and goes in the message
whole, under its categories. Besides the scope bundle, this skill has
nothing to write to disk; a Write call during a review is the report leaving the page.

## Report example

```
📊 CODE REVIEW REPORT
Scope: user/service.go, user/auth.go (+ tests) · Mode: FULL
Hunters: R1 2/2 · R2 1/1 · R3 1/1 (findings returned/rendered) · R4–R8 skipped
         (a hunter's not-reached line, when it returned one, follows its tally here)
Skeptic: 1 extraction CONFIRMED, 1 REFUTED (score 1 → rename instead)
Critic: 14 comments reviewed — 11 KEEP · 2 REWRITE · 1 DELETE

🔴 DESIGN DEBT                       (one finding per line, never wrapped)
user/service.go:67 | R1 Q1: the session token is validated inline as a raw string, no ParseX owns it; Q2: the same emptiness predicate at user/auth.go:41 — two owners | Replace Primitive with Domain Type: SessionToken — skeptic CONFIRMED (score 5) | M
user/auth.go:34 | R2 Q1: Authenticator.HashCost is exported, so a literal builds an invalid Authenticator; Q2: Verify re-checks the range at auth.go:52 | Add validating constructor: NewAuthenticator | S

🟡 READABILITY DEBT
user/auth.go:89 | R3 Q2: Authenticate mixes the auth flow with bcrypt byte handling in one body; Q3: the block comment `// compare password` names the section | Extract Function named after the comment: comparePassword | S
user/service.go:15 | critic: the godoc restates the name ("UserService provides user services") — toolbox-value floor, no toolbox item delivered | REWRITE → wider context: "Every user mutation flows through this service — auth, quota, and audit hooks attach here." | S

🟢 POLISH
user/auth.go:12 | ComparePasswordWithHash → PasswordMatches — skeptic's cheaper alternative to REFUTED PasswordHash wrapper (score 1: only method unwraps) | S

📝 BROADER CONTEXT
user/service.go:23 — email still a raw string (outside diff scope; same R1 pattern).

Caller decides: commit as-is · fix 🔴 first · fix all. Findings are advisory.
```
