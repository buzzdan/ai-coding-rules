Determine the doc root first (discovery order above); `<docroot>` below is that
directory. Q1–Q3 and Q7 are fully mechanical: the plugin ships them as
`scripts/check-repo-brain.sh` (installed into the repo by the bootstrap pass), so
one command answers all four.

1. **Is any doc an orphan?**
   Detection: `find <docroot> -name '*.md' ! -name 'index.md'` versus the link
   targets extracted from `index.md` and any sub-indexes, e.g.
   `grep -oE '\]\([^)]+\.md\)' <docroot>/index.md`.
   Violation: a doc file no index references — unreachable from the root, so
   unread, so rotting. Cite the file and the index that should list it.

2. **Is any edge broken — in either direction?**
   Detection, code→docs: `grep -rnoE '(docs|\.ai|\.ainav)/[A-Za-z0-9._/-]+\.md' --include='*.go' .`
   plus `.md`-to-`.md` links inside `<docroot>`; `test -f` each target.
   Detection, docs→code: build the repo's declaration set once — single-line
   and grouped `type (` / `var (` / `const (` declarations, functions, and
   methods — and resolve each backticked symbol against it. A token missing
   from the set still resolves when it appears as a whole word in any
   non-markdown repo file (config keys, alert names, test helpers). A
   package-qualified `pkg.Sym` whose package is not declared in this repo is
   external (stdlib, dependencies) and exempt. For a cited package or
   directory path, `test -d` it.
   Violation: any unresolved target in either direction. Additionally, a doc citing
   a **file path or line number** is itself a violation of the edge policy —
   regardless of whether the coordinate currently resolves. Exempt from the
   ban: URL spans (e.g. pkg.go.dev links), fenced code blocks, and glob
   patterns (a span containing `*` is a pattern, not a citation).
   Two exemptions, both scoped to symbol resolution and both per-LINE — a line
   carrying either marker is skipped whole (the file-path ban has no exemption
   beyond URLs): a line carrying the ⚠️ stale flag (cites an unresolved
   `Symbol`) is a recorded finding, not a broken edge — the decision to
   refresh, remove, or keep it is the user's. And backticks are a resolvability
   contract — a future/roadmap symbol is written in prose or explicitly marked
   *(planned)*, and a *(planned)*-marked line is exempt from resolution.

3. **Is the root unwired?**
   Detection: for each doc root, `grep -l '<docroot>/index.md' CLAUDE.md AGENTS.md
   2>/dev/null` in the root's owning project directory — the exact path, never a
   bare `index.md` mention. A monorepo sub-root also counts as wired when the
   repo-root index links into it.
   Violation: no hit anywhere — the map exists but is not in context at session
   start; the `@<docroot>/index.md` import is missing.
   Advisory: CLAUDE.md is wired but AGENTS.md lacks the routing reference — every
   tool that reads AGENTS.md instead of CLAUDE.md starts blind.

4. **Does a doc comment on an exported symbol state WHAT instead of WHY?**
   Detection: for each exported declaration in the diff
   (`grep -nE '^(type|func) [A-Z]' <changed files>`), read its doc comment and
   compare its tokens against the identifier and the first lines of the body — a
   comment whose content is recoverable from the name or the code adds nothing.
   Violation: the comment restates the identifier (`// Policy is a policy`) or
   narrates the implementation, instead of carrying rationale, constraints, or
   context the code cannot. Boundary: block comments *inside* function bodies are
   NOT this question — they are `R3-storifying.md` Q3 (extraction candidates).

5. **Is new exported API naked, or a feature-sized change undocumented at rung 2?**
   Detection: in the diff, `grep -nE '^(type|func) [A-Z]'` on added lines and check
   each for a preceding `//` doc comment; separately, compare new packages or entry
   points in the diff against `<docroot>` contents.
   Violation: a new exported type or package with no doc comment; or a
   feature-sized diff (new package, new entry point) with no doc-root entry —
   the knowledge shipped without joining the network.

6. **Did behavior change silently under an existing doc?** *(advisory)*
   Detection: map the diff's changed packages to docs that cite their symbols or
   package paths (grep `<docroot>` for the package name and its exported symbols);
   check whether any such doc is in the diff.
   Violation (advisory): a package with a citing feature doc changed and the doc
   did not — flag it with the doc's path as evidence; the fix is updating the
   affected section, never appending history.

7. **Does any file break the bundle contract?**
   Detection: every content `.md` under `<docroot>` starts with a terminated
   frontmatter block (first line `---`, a closing `---` follows) carrying
   `type` valued `feature` / `architecture` / `guide` and a non-empty
   `description`. Index files carry NO frontmatter — except the root index,
   whose block is exactly one `okf_version: "0.2"` (required there, forbidden
   everywhere else). `grep -rn '^related:'` over doc-root
   frontmatter; `find <docroot> -name 'log.md'`. For every index line shaped
   `- [doc](path) — text`, compare the text against the target's `description`
   when it has one (⚠️-flagged lines exempt — recorded findings, not copies;
   bare sub-index targets have no `description` and are skipped); the script's
   `--fix` flag rewrites drifted lines from the descriptions.
   Violation: a missing or unterminated frontmatter block on a content doc; a
   missing or invalid required key (a `type` outside the three classes, an
   empty `description`); frontmatter on a sub-index; any key besides
   `okf_version` on the root index; a missing, duplicated, or mis-valued root
   `okf_version`; a `related:` key anywhere; a `log.md` anywhere in the doc
   root; an index line that drifted from the `description` it copies.
   Advisory branch: a doc whose `stale_after` is in the past (or
   `status: deprecated`) with no ⚠️ on its index line — recorded staleness the
   map does not show; the fix is re-copying the line (drift-check rule above).
