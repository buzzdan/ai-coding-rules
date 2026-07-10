---
name: pre-commit-review
description: |
  ADVISORY pre-commit review that orchestrates parallel single-obsession rule hunters and an over-abstraction skeptic against the diff.
  Spawns read-only agents (rule-hunter, overabstraction-skeptic); NEVER edits code.
  Invoked by @linter-driven-development (Phase 4), by @refactoring (after pattern application), or manually for standalone code review.
  Categorizes findings as Bugs, Design Debt, Readability Debt, or Polish Opportunities. Does NOT block commits.
allowed-tools:
  - Read
  - Grep
  - Bash
  - Task
---

<objective>
Verify a finished diff against the plugin's rules (R1–R11) with evidence, by orchestrating
parallel single-obsession `rule-hunter` agents and one `overabstraction-skeptic`.
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

<step_4_merged_report>
Merge surviving findings into one report. Category mapping:

- 🐛 **Bugs** — will fail at runtime regardless of rule (nil returned as a value,
  cancellation swallowed by `context.Background()`, R10 goroutine leaks and
  unguarded concurrent writes): fix immediately.
- 🔴 **Design Debt** — R1, R2, R4, R6, R7, R8, R10's non-crash findings (production
  sleeps, fire-and-forget ownership, mutex placement), R11 (duplicated discriminators,
  boundary leaks), and R5 (advisory — never blocks; the user may have valid reasons):
  fix before commit recommended.
- 🟡 **Readability Debt** — R3, R9, unclear naming: improves maintainability.
- 🟢 **Polish** — minor idiomatic improvements, the skeptic's cheaper alternatives.

Every finding carries evidence — `file:line` plus the falsifying-question answer or
command output — never a bare verdict. Effort carries over from the hunter (S/M/L).
Fix routing is each rule file's **Fix pattern** section; cite it, don't restate it.
Issues noticed outside the diff scope go in a BROADER CONTEXT section, not as findings.
</step_4_merged_report>

</protocol>

<modes>
**FULL (first run):** pre-filter all eleven rules over the whole diff scope; report every
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
- Spawn anything other than `rule-hunter` and `overabstraction-skeptic`
</constraints>

<who_invokes>
1. **@linter-driven-development** — Phase 4, pre-commit / per completed vertical slice
2. **@refactoring** — after applying patterns, to validate design quality (INCREMENTAL)
3. **User** — manual standalone review before commit
</who_invokes>
