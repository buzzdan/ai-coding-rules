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
2. Existing docs inventoried and classified (stale docs indexed with a ⚠️ flag)
3. `index.md` built — short, grouped, one line per doc (map of maps past ~300 lines)
4. CLAUDE.md wired with the `@<docroot>/index.md` import (AGENTS.md: plain reference)
5. **Upward edges wired**: every confidently-anchorable doc gets its one-line
   `// See <docroot>/<file>.md ...` edge on its front-door symbol
6. R9 confirmation pass + the advisory findings report (broken edges, edge-policy
   violations, rung-2 gaps, stale/unwired docs)

**What this command does NOT do** (by design — the skill's constraints):
- Generate or rewrite content docs — gaps are reported for FEATURE mode to fill
- Decide the fate of stale docs — refresh / remove / keep-as-roadmap is your call
- Touch anything beyond doc files, `index.md`, CLAUDE.md/AGENTS.md, and one-line
  godoc edge additions (verified with `go vet` after each)

When it finishes, review the report, then `git diff` — the changes should read as
pure documentation-network wiring. Re-run any time: the pass is idempotent (existing
index lines are refreshed, existing edges and wiring are verified, not duplicated).
