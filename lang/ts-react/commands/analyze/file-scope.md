**Resolve the scope** — the first rung that applies, and only that rung:

1. **An argument names it** (`$ARGUMENTS`). A file pattern (`./src/pages/Devices/*.tsx`,
   `./src/pages/Devices/`) analyzes those files — validate they exist with glob/ls. `--all`, or
   an explicit request to audit the whole repository, analyzes every `.ts` and `.tsx` file
   outside `node_modules/`, `dist/`, `build/`, `.next/`, `coverage/` and generated `*.d.ts`
   and `*.generated.ts` files. The whole repository is never analyzed without being asked.
2. **The working tree.** Files changed against `HEAD`, staged, unstaged and untracked:
   ```bash
   { git diff --name-only --diff-filter=ACMR HEAD; git ls-files --others --exclude-standard; } | grep -E '\.tsx?$' | sort -u
   ```
3. **The current PR.** With a clean tree, the files changed on this branch since its base
   (the merge-base shown in the preamble). This is the ceiling: never wider than the branch.
   ```bash
   git diff --name-only --diff-filter=ACMR "$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || git merge-base HEAD master)"..HEAD | grep -E '\.tsx?$'
   ```
4. **Nothing.** Say "nothing to analyze", name the `--all` form, and stop — no gates run
   over an empty scope, and the scope is never widened silently.

Name the rung in the report's scope line.
