Determine the doc root first (discovery order above); `<docroot>` below is that
directory. Q1–Q3 and Q7 are fully mechanical: the plugin ships them as
`scripts/check-repo-brain.sh` (installed into the repo by the bootstrap pass), so
one command answers all four. Code-side searches run over `*.ts` and `*.tsx` files
outside `node_modules`.

1. **Is any doc an orphan?**
   Detection: `find <docroot> -name '*.md' ! -name 'index.md'` versus the link
   targets extracted from `index.md` and any sub-indexes, e.g.
   `grep -oE '\]\([^)]+\.md\)' <docroot>/index.md`.
   Violation: a doc file no index references — unreachable from the root, so
   unread, so rotting. Cite the file and the index that should list it.

2. **Is any edge broken — in either direction?**
   Detection, code→docs: `grep -rnoE '(docs|\.ai|\.ainav)/[A-Za-z0-9._/-]+\.md' --include='*.ts' --include='*.tsx' --exclude-dir=node_modules .`
   plus `.md`-to-`.md` links inside `<docroot>`; `test -f` each target.
   Detection, docs→code: build the repo's declaration set once — top-level
   functions, `const`/`let`/`var` bindings, classes and their methods, interfaces,
   types and enums, exported or not, each owned by its module (file stem; `index`
   takes the directory's name) and by the directory holding it — and resolve each
   backticked symbol against it. A token missing from the set still resolves when
   it appears as a whole word in any non-markdown repo file (config keys, route
   paths, test helpers). A qualified `Namespace.member` whose namespace is not
   declared in this repo (`React.useState`, `Intl.DateTimeFormat`) is external
   (the platform, dependencies) and exempt. For a cited package or directory path,
   `test -d` it.
   Violation: any unresolved target in either direction. Additionally, a doc citing
   a **file path or line number** is itself a violation of the edge policy —
   regardless of whether the coordinate currently resolves. Exempt from the
   ban: URL spans (a docs-site link, say), fenced code blocks, and glob
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

4. **Does a JSDoc on an exported symbol state WHAT instead of WHY?**
   Detection: for each exported declaration in the diff
   (`grep -nE '^export (default )?(async )?(function|const|class|type|interface|enum) [A-Za-z]' <changed files>`),
   read the JSDoc block above it. The summary line is the contract in one sentence
   and is exempt from the restatement verdict when it states that contract
   (`/** A named, validated service port; it cannot exist out of range. */` earns
   its line); it is a finding when it restates the name (`/** Policy is a policy.
   */`; `/** Gets the user. */` on `getUser`; `/** The cluster id. */` on
   `clusterId: string`). The body is judged like any other comment: compare its
   tokens against the identifier, the type signature and the first lines of the
   code — a paragraph whose content is recoverable from the name, the types or the
   code adds nothing. `@param` and `@returns` tags count only when they carry what
   the type cannot (units, ownership, who calls it); tags that restate the
   signature's types, and `@type` tags, are noise. A component's props doc the prop
   whose meaning its type does not carry, never every prop.
   Violation: a summary line that restates the identifier, or a body that narrates
   the implementation, instead of carrying rationale, constraints, or context the
   code cannot. Boundary: `//` comments *inside* function bodies are NOT this
   question — they are `R3-storifying.md` Q3 (extraction candidates).

5. **Is new exported API naked, or a feature-sized change undocumented at rung 2?**
   Detection: in the diff, `grep -nE '^\+export (default )?(async )?(function|const|class|type|interface|enum) [A-Za-z]'`
   on added lines and check whether the preceding added line closes a JSDoc block
   (`*/`). Where the repository configures `eslint-plugin-jsdoc`,
   `jsdoc/require-jsdoc` is this check made mechanical, and an
   `// eslint-disable-next-line jsdoc/require-jsdoc` on the declaration is the naked
   export with its marker silenced. Non-exported symbols carry no `jsdoc` obligation
   and no JSDoc debt here. Separately, compare new page folders, routes or
   `services/<domain>Api.ts` modules in the diff against `<docroot>` contents.
   Violation: a new exported function, component, hook, class or type with no JSDoc;
   or a feature-sized diff (new page folder, new route, new API domain) with no
   doc-root entry — the knowledge shipped without joining the network.

6. **Did behavior change silently under an existing doc?** *(advisory)*
   Detection: map the diff's changed modules and page folders to docs that cite
   their symbols or directory paths (grep `<docroot>` for the folder name and its
   exported symbols); check whether any such doc is in the diff.
   Violation (advisory): a module with a citing feature doc changed and the doc
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
