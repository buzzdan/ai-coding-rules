**Resolve the scope** — the first rung that applies, and only that rung:

1. **An argument names it** (`$ARGUMENTS`). A file pattern (`./pkg/parser/*.go`,
   `./pkg/parser/`) analyzes those files — validate they exist with glob/ls. `--all`, or
   an explicit request to audit the whole repository, analyzes every `.go` file outside
   `vendor/` and `testdata/`. The whole repository is never analyzed without being asked.
2. **The working tree.** Files changed against `HEAD`, staged, unstaged and untracked:
   ```bash
   { git diff --name-only --diff-filter=ACMR HEAD; git ls-files --others --exclude-standard; } | grep '\.go$' | sort -u
   ```
3. **The current PR.** With a clean tree, the files changed on this branch since its base
   (the merge-base shown in the preamble). This is the ceiling: never wider than the branch.
   ```bash
   git diff --name-only --diff-filter=ACMR "$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || git merge-base HEAD master)"..HEAD | grep '\.go$'
   ```
4. **Nothing.** Say "nothing to analyze", name the `--all` form, and stop — no gates run
   over an empty scope, and the scope is never widened silently.

Name the rung in the report's scope line.
