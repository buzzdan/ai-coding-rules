---
type: guide
description: how to maintain this doc root (read before editing docs)
---
# Doc Conventions

This directory is the repo's documentation network — an OKF v0.2 bundle, kept to the
stricter profile the Go plugin's rule R9 describes. Markdown files with YAML
frontmatter; `index.md` is the map; links form the graph. The plugin that lives in
this repo enforces these rules on other repos, so this doc root follows them too.

## Frontmatter
Every content doc here starts with frontmatter (copy-paste, fill in):

    ---
    type: feature            # feature | architecture | guide
    description: <one line — this IS the doc's line in index.md>
    ---

Optional on content docs: `title`, `generated` (ISO 8601, last substantive
update), `tags`, `status: draft|stable|deprecated`, `stale_after: <date>`.
Index files carry NO frontmatter — except the root `index.md`, which carries
only `okf_version`.

## Links
- The index line for a doc IS its `description` — the description is the single
  source: update it in the doc's frontmatter, copy it to `index.md`, and the
  conformance gate fails when the two drift.
- Cite code by exported symbol (`<Type>` or `<Type>.<Method>`), never by file
  path or line number. Backticks are a promise: a backticked symbol must grep in
  this repo (mark future ones *(planned)* and write them without backticks).
  Paths to directories and scripts are fine when the thing has no symbol.
- Link related docs inline, in the sentence that explains the relationship.
  Links are one-way: never add a link back to `index.md` or a parent.
  Use inline markdown links only; reference-style links are not checked by the
  conformance gate. There is no `## Related` section.

## Never
- No `log.md`, no changelog sections — docs describe current behavior, not history.
- No `related:` key in frontmatter — links live in the body.
- No frontmatter on index files (the root's `okf_version` is the one exception).
- No file paths or line numbers as code references.

## Check your work
Run `bash scripts/check-docs.sh` (or `task docs:check`) from the repo root. It runs the
plugin's own conformance gate over the files git tracks, so ignored paths such as a
local `.evals/` clone never affect the result; anything it reports is real. `--fix`
rewrites drifted index lines from each doc's `description`. Code↔docs checks cover
Go files; docs about shell scripts and markdown get the structure checks
(reachability, frontmatter, index drift) but no symbol verification.
