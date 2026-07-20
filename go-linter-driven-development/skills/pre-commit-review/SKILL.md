---
name: pre-commit-review
description: |
  ADVISORY pre-commit review that orchestrates parallel single-obsession rule hunters, an over-abstraction skeptic, and a comment critic against the diff.
  Spawns read-only agents (rule-hunter, overabstraction-skeptic, comment-critic); NEVER edits code.
  Invoked by @linter-driven-development (Phase 4), by @refactoring (after pattern application), or manually for standalone code review.
  Categorizes findings as Bugs, Design Debt, Readability Debt, or Polish Opportunities. Does NOT block commits.
allowed-tools:
  - Read
  - Grep
  - Bash
  - Task
---

<objective>
Verify a finished diff against the plugin's rules (R1–R12) with evidence, by orchestrating
parallel single-obsession `rule-hunter` agents, one `overabstraction-skeptic`, and one
`comment-critic`.
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
- **Diff scope**: staged changes by default (`git diff --cached --name-only -- '*.go'`),
  or an explicit file list / diff range from the caller.
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
| R2 | `../../rules/R2-self-validating-types.md` | invalid-state construction; defensive re-checks; nil as a value |
| R3 | `../../rules/R3-storifying.md` | mixed abstraction levels; comments naming unextracted blocks |
| R4 | `../../rules/R4-helper-placement.md` | helper visibility/placement off the placement ladder |
| R5 | `../../rules/R5-vertical-slice.md` | horizontal layering; role-named packages |
| R6 | `../../rules/R6-test-only-interfaces.md` | interfaces whose only second implementer is a test double |
| R7 | `../../rules/R7-test-placement.md` | internal test packages; wantErr conditionals; wrong-rung tests; sleeps |
| R8 | `../../rules/R8-no-globals.md` | package-level state; `context.Background()` in library code |
| R9 | `../../rules/R9-repo-brain.md` | orphan docs; broken doc edges (both directions); WHAT-comments on exported API; unwired root |
| R10 | `../../rules/R10-concurrency-safety.md` | goroutines without exit paths or owners; unguarded shared-state writes; production sleeps; decorative mutexes |
| R11 | `../../rules/R11-conditional-dispatch.md` | one discriminator switched in ≥2 places; type switches in domain logic; unknown-kind defaults away from the boundary; flag arguments; unearned dispatch abstractions (inverse) |
| R12 | `../../rules/R12-mutation-discipline.md` | internal slices/maps returned by reference; constructors aliasing caller collections; query/modifier hybrids; setters around validating constructors; ceremony copies (inverse) |

Also in-context: a new `//nolint` directive or `.golangci.yaml` exclusion in the diff is
itself a finding — the change must justify, with evidence, that the rule genuinely does
not apply.
</step_1_grep_prefilter>

<step_2_spawn_hunters>
For every rule with pre-filter hits, spawn one `rule-hunter` agent — all hunters in a
single message, in parallel. Each spawn prompt MUST contain:

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
plus a final tally line (`R<N>: <M> finding(s)` or a hunted-clean line).
</step_2_spawn_hunters>

<step_3_skeptic_pass>
Collect ALL type/package-extraction findings — every R1/R2/R4 "create a type/package"
proposal, R10 "Extract Synchronized Owner" proposals, and R11 "Interface Dispatch" /
"Strategy Map" proposals — and spawn one `overabstraction-skeptic`. Its spawn prompt MUST contain:

1. The extraction findings under review — the hunter blocks pasted verbatim.
2. Payload: the **Juiciness scoring** and **The over-abstraction trap** sections of
   `../../rules/R1-primitive-obsession.md`, pasted.
3. Payload: the FULL content of `../../examples/overabstraction-cidr.md`, pasted.

Verdicts per finding: `CONFIRMED (score + verified evidence)` or
`REFUTED (score 0–1 + reason) → cheaper alternative`. A refuted proposal does not ship;
when its cheaper alternative (better naming, private fields + accessors, or R11's
Keep the Single Exhaustive Switch) is still worth doing, report the alternative as
🟢 Polish. When R11 dispatch proposals are under review, additionally paste the FULL
content of both R11 case files — `../../examples/anti-if-dispatch.md` (Move 3 is the
juiciness rejection: the switch stays, goes exhaustive) and
`../../examples/switch-to-polymorphism.md` (the dependency-direction rejection: the
move is unavailable when the consumer owns the output format; the switch shrinks to
pure dispatch). Only findings the skeptic cannot kill ship as extraction
findings. Non-extraction findings (R3, R5–R9, and R1/R2/R10/R11 findings that propose
no new type) skip the skeptic and go straight to the report — R9 findings (orphans,
broken edges, WHAT-comments, unwired root) propose no type extractions.
</step_3_skeptic_pass>

<step_3b_comment_critic>
When the diff contains comment lines — prefilter:
`git diff --cached -- '*.go' | grep -E '^\+.*//' | grep -vE '//(go:|nolint| Output:)'`
(any hit qualifies; directives don't count) — spawn one `comment-critic` alongside
the skeptic (same message when both run). Its spawn prompt MUST contain:

1. Payload: R9's **Comment policy** section (`../../rules/R9-repo-brain.md`,
   Design guidance) pasted verbatim — the Comment Value Toolbox kinds, the
   three-test standard, the tier table and budget accounting.
2. Payload: the **Comment Value Toolbox** catalog section of
   `../documentation/reference.md` (resolve to an absolute path) pasted verbatim.
3. The diff scope.

It judges every comment in the diff (godoc, in-body, test) against the three-test
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

**Cluster pass (before categorizing):** group surviving findings by shared anchor —
the same type, field/discriminator, or function named in ≥2 findings from *different*
rules. Each hunter is single-obsession and blind to the others, so independent
convergence on one anchor is evidence that a domain concept is missing there — the
cluster is a juiciness scorecard that filled itself in (R1 hunter sees the raw
primitive, R11 the duplicated switch, R2 the ownerless validation: one disease, four
jurisdictions). Render each cluster as a first-class entry above the categories:

```
🔗 CLUSTER: Alert.Channel (4 findings: R1, R11, R2, R7)
   Hypothesis: missing domain concept — a Channel type wants to exist
   Routing: design-first — @code-designing (cluster-scoped), then @refactoring
   implements; do NOT fix members independently (partial fixes undo each other)
```

Member findings still appear under their categories below, tagged
`[cluster: <anchor>]`. Clustering is *reporting* — this skill still never edits and
never invokes fix skills; the caller routes.

Category mapping:

- 🐛 **Bugs** — will fail at runtime regardless of rule (nil returned as a value,
  cancellation swallowed by `context.Background()`, R10 goroutine leaks and
  unguarded concurrent writes): fix immediately.
- 🔴 **Design Debt** — R1, R2, R4, R6, R7, R8, R10's non-crash findings (production
  sleeps, fire-and-forget ownership, mutex placement), R11 (duplicated discriminators,
  boundary leaks), R12 (leaked mutable internals, unvalidated setters), and R5
  (advisory — never blocks; the user may have valid reasons): fix before commit
  recommended.
- 🟡 **Readability Debt** — R3, R9, unclear naming, and the comment-critic's
  non-KEEP verdicts (trash or over-budget or hard-to-read comments): improves
  maintainability.
- 🟢 **Polish** — minor idiomatic improvements, the skeptic's cheaper alternatives.

Every finding carries evidence — `file:line` plus the falsifying-question answer or
command output — never a bare verdict. Effort carries over from the hunter (S/M/L).
Fix routing is each rule file's **Fix pattern** section; cite it, don't restate it.
Issues noticed outside the diff scope go in a BROADER CONTEXT section, not as findings.
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
Scope: user/service.go, user/auth.go (+ tests) · Mode: FULL
Hunters: R1 (2 leads), R2 (1), R3 (1) · R4–R8 skipped (no pre-filter hits)
Skeptic: 1 extraction CONFIRMED, 1 REFUTED (score 1 → rename instead)
Critic: 14 comments reviewed — 11 KEEP · 2 REWRITE · 1 DELETE

🔴 DESIGN DEBT
user/service.go:67 | session token travels as raw string; emptiness check inline
  (R1 Q1: yes; Q2: same predicate at user/auth.go:41 — two owners) | Replace
  Primitive with Domain Type: SessionToken — skeptic CONFIRMED (score 5) | M
user/auth.go:34 | Authenticator.HashCost exported; methods re-check its range
  (R2 Q1: literal construction possible; Q2: re-check at auth.go:52) | validating
  constructor NewAuthenticator | S

🟡 READABILITY DEBT
user/auth.go:89 | Authenticate() mixes auth flow with bcrypt byte handling
  (R3 Q1: two abstraction levels in one body) | Extract Step: comparePassword | S
user/service.go:15 | godoc restates the name ("UserService provides user services")
  (critic: toolbox-value floor — no toolbox item delivered) | REWRITE → wider
  context: "Every user mutation flows through this service — auth, quota, and
  audit hooks attach here." | S

🟢 POLISH
user/auth.go:12 | ComparePasswordWithHash → PasswordMatches — skeptic's cheaper
  alternative to REFUTED PasswordHash wrapper (score 1: only method unwraps) | S

📝 BROADER CONTEXT
user/service.go:23 — email still a raw string (outside diff scope; same R1 pattern).

Caller decides: commit as-is · fix 🔴 first · fix all. Findings are advisory.
```
</report_example>

<constraints>
This skill MUST NOT:
- Edit code, fix findings, or invoke fix skills (@refactoring, @code-designing, @testing)
- Run the linter or tests — the caller does (see @linter-driven-development)
- Block commits — every finding is advisory; the caller decides what to fix
- Restate rule content — rules live once in `../../rules/`; paste them as spawn payload
  and cite them in findings
- Spawn anything other than `rule-hunter`, `overabstraction-skeptic`, and
  `comment-critic`
</constraints>

<who_invokes>
1. **@linter-driven-development** — Phase 4, pre-commit / per completed vertical slice
2. **@refactoring** — after applying patterns, to validate design quality (INCREMENTAL)
3. **User** — manual standalone review before commit
</who_invokes>
