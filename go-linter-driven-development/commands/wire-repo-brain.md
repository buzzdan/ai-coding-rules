---
name: wire-repo-brain
description: Wire the full documentation network in one pass — code comments → docs → index.md → CLAUDE.md
argument-hint: "[path to repo or sub-project root (default: cwd)]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
  - Edit
  - Skill(go-linter-driven-development:documentation)
---

Wire this repo's **repo brain** end to end, in a single pass.

Invoke `Skill(go-linter-driven-development:documentation)` and run its **BOOTSTRAP
mode** against `$ARGUMENTS` (default: the current repo root). The skill's protocol is
authoritative; this command adds nothing to it. One pass delivers the whole chain:

1. Doc root discovered (`.ai/` → `.ainav/` → `docs/`; per sub-project in a monorepo)
2. Existing docs inventoried and classified (stale docs indexed with a ⚠️ flag);
   OKF frontmatter verified-or-added (un-inferable types reported)
3. `index.md` built — frontmattered, short, grouped, one line per doc derived from
   each doc's `description` (directory-shaped map of maps past ~300 lines)
4. AGENTS.md routing block authored once (root, and nested per sub-project in a
   monorepo); CLAUDE.md embeds it (`@AGENTS.md`) + the `@<docroot>/index.md` import
5. `<docroot>/conventions.md` created/verified (listed first in the index) and the
   plugin's `scripts/check-repo-brain.sh` installed — the report suggests the CI
   one-liner
6. **Upward edges wired**: every confidently-anchorable doc gets its one-line
   `// See <docroot>/<file>.md ...` edge on its front-door symbol
7. R9 confirmation pass — Q1–Q3 and Q7 via the installed script — + the advisory
   findings report (broken edges, edge-policy violations, rung-2 gaps,
   stale/unwired docs, types needing a human call)

**What this command does NOT do** (by design — the skill's constraints):
- Generate or rewrite content docs — gaps are reported for FEATURE mode to fill
  (conventions.md and the copied check script are the two sanctioned artifacts)
- Decide the fate of stale docs — refresh / remove / keep-as-roadmap is your call
- Add CI workflows — the report only suggests `bash scripts/check-repo-brain.sh`
- Touch anything beyond doc files, `index.md`, `conventions.md`,
  CLAUDE.md/AGENTS.md, the copied check script, and one-line godoc edge additions
  (verified with `go vet` after each)

When it finishes, review the report, then `git diff` — the changes should read as
pure documentation-network wiring. Re-run any time: the pass is idempotent (existing
index lines are refreshed from frontmatter; existing edges, wiring, conventions, and
the script are verified, not duplicated — a repo wired by an older plugin version
converges to the current rules in one pass).
