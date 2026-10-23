# ruff — the lint-setup reference

<!-- residue-exempt: this reference names ruff, its rule codes, its CI actions and its hooks on purpose. -->

The lint-setup skill reads this file in the step that names it. Before you use a flag,
make sure that the installed version has it: `ruff check --help`. `<tmp>` is a
temporary directory outside the repository, for example from `mktemp -d`. `<rec>` is
the recommended config, `<this skill dir>/../../setup/ruff.toml`.

## The doctor's rows

ruff reports each setting, so the rows show the values on both sides. The doctor runs
the ruff on PATH only. When it says that ruff is not on PATH, tell the user to
activate the project's virtual environment (or to put the project's ruff on PATH in
another way), and run the doctor again. The recipes below run the same ruff: the one
on PATH. A preview rule
(for example `PLR1702`) runs only in preview mode: `<rec>` sets `preview = true` and
`explicit-preview-rules = true`, so that no other preview rule turns on.

## Count the findings (step 4)

ruff takes a setting on the command line (`--config '<key> = <value>'`) on top of the
project's own config. The project's paths and exclusions thus stay as they are, and
the count needs no temporary config.

**Run A, every recommended value**, from the project root:

```sh
ruff check --no-cache --no-fix --exit-zero --statistics \
  --extend-select C901,PLR0913,PLR1702 \
  --config 'lint.mccabe.max-complexity = 8' \
  --config 'lint.pylint.max-args = 4' \
  --config 'lint.preview = true' --config 'lint.explicit-preview-rules = true' .
```

Put each rule code of `<rec>` in `--extend-select`, and one `--config` per setting of
`<rec>`. The example shows three of them. `--statistics` prints one line per rule code
with its count.

**Run B, the project's own config:** `ruff check --no-cache --no-fix --exit-zero --statistics .`

**One more value, only when the user asks for it:** run A with `--select <code>` in
place of `--extend-select`, and that one value.

## New issues only (steps 3 and 5)

ruff has no setting that checks new issues only. The forms a team may already use: a
task or a hook that runs ruff on the changed files only (the pre-commit hook of ruff
checks the files of the commit); reviewdog with `-filter-mode=added` or
`filter_mode: added`; `astral-sh/ruff-action` with the changed files in `src`.

Ladder step 2 has two options. Offer both, and say why:

- **Option a, "fix each file you touch":** ruff runs on the changed files only. No
  tool to add. The cost: a change of one line in a large file makes its author fix
  the whole file.
- **Option b, "new lines only":** only an added line can fail. It needs reviewdog:
  install it only when the user agrees to that line of the plan. Recommend option b
  when the project has very large files.

Each is a new task; the CI step and the hook call it. `<base>` is the ref of the
branch the team merges into, for example `origin/main`. Each task first finds the
merge base, and fails with a message when `<base>` is not there: else a clone without
that ref passes with no check. `git diff --relative` gives the paths from the
directory of the task file, so the task also works in a project below the git root.
`-z` with `xargs -0` keeps a path with a space whole. A Taskfile with option a:

```yaml
  lint-changed:
    desc: ruff on the Python files changed since the merge base with <base>; paths after -- replace that list
    cmds:
      - |
        set -o pipefail
        if [ -n "{{.CLI_ARGS}}" ]; then ruff check --force-exclude {{.CLI_ARGS}}; exit; fi
        base=$(git merge-base HEAD <base>) || { echo "lint-changed: no merge base with <base>; fetch <base> first" >&2; exit 1; }
        { git diff --relative --name-only -z --diff-filter=d "$base" -- '*.py'
          git ls-files -z -o --exclude-standard -- '*.py'; } \
          | xargs -0 sh -c '[ "$#" -eq 0 ] || ruff check --force-exclude "$@"' sh
```

The list holds the changed files and the new files that git does not track yet. The
`sh` guard keeps an empty list from checking the whole project. `pipefail` makes the
task fail when git fails. With option b:

```yaml
  lint-new:
    desc: ruff on the lines added since the merge base with <base>; paths after -- narrow the run
    cmds:
      - |
        set -o pipefail
        base=$(git merge-base HEAD <base>) || { echo "lint-new: no merge base with <base>; fetch <base> first" >&2; exit 1; }
        diff=$(mktemp); trap 'rm -f "$diff"' EXIT
        git diff --relative "$base" > "$diff"
        git ls-files -o --exclude-standard -- '*.py' | while IFS= read -r f; do
          git diff --no-index /dev/null "$f" >> "$diff"
        done
        ruff check --exit-zero --output-format=rdjson {{.CLI_ARGS}} | reviewdog -f=rdjson -reporter=local -filter-mode=added -fail-level=any -diff="cat $diff"
```

The diff holds the changed files and each new file that git does not track yet, so
each line of a new file is an added line. `--exit-zero` keeps a finding on an old line
from failing the task: reviewdog decides.
`pipefail` makes the task fail when ruff itself fails, for example on a config that
does not load.

reviewdog exits non-zero on a finding only with `-fail-level=any`; an older version
uses `-fail-on-error`. Check `reviewdog -help`.

## The strict file (ladder step 3)

Name: `ruff.strict.toml`, beside the original. It extends the original, and it adds
rules with `extend-select` only:

```toml
extend = "pyproject.toml"  # the original config, relative to this file

[lint]
extend-select = ["C901", "PLR0913"]

[lint.mccabe]
max-complexity = 8
```

The strict file must not have:

- `select`: it replaces the rule set of the original;
- `ignore`, `per-file-ignores` or `extend-per-file-ignores`;
- `exclude`, `extend-exclude`, `include` or `lint.exclude`;
- a looser limit, or `preview = false` when the original sets it to `true`;
- a change to any other setting.

`ruff check --config ruff.strict.toml` uses that one file for every source file. When
the project has a config in a subdirectory too, tell the user that the strict run does
not read it.

The task that runs it, in a Taskfile:

```yaml
  lint-strict:
    desc: ruff with the strict config; paths after -- narrow the run
    cmds:
      - ruff check --config ruff.strict.toml {{.CLI_ARGS}}
```

In a Makefile:

```make
ARGS ?= .
lint-strict:
	ruff check --config ruff.strict.toml $(ARGS)
```

## The superset check (step 7)

**Check each run before you compare.** A run that fails, or a list that is not
there, compares nothing: `comm` then prints nothing, and that looks like a pass.
When a run exits with an error, or when `<tmp>/original.txt` or `<tmp>/strict.txt`
is not there, say "cannot check the superset", with the cause from stderr. Never say
that the superset holds.

1. Read the strict file: it extends the original, and it holds none of the forbidden
   keys above.
2. The findings on the current tree, from the project root:
   `ruff check --no-cache --no-fix --exit-zero --quiet --output-format concise . > <tmp>/original.txt`
   and
   `ruff check --no-cache --no-fix --exit-zero --quiet --output-format concise --config ruff.strict.toml . > <tmp>/strict.txt`.
   With `--exit-zero`, each run must exit 0: another exit code means that ruff
   failed, for example on a config that does not load.
3. Keep the place and the rule of each finding, and sort:
   `cut -d' ' -f1,2 <tmp>/original.txt | sort > <tmp>/original.sorted`, and the same
   for the strict list. The message holds the limit (`(3 > 2)`, `(3 > 1)`), so a
   stricter limit changes it: compare the place and the rule only.
4. `comm -23 <tmp>/original.sorted <tmp>/strict.sorted` must print nothing. Each line
   that it prints is a finding of the original that the strict file lets pass: show
   it, and correct the strict file.
5. Tell the user that this checks the current tree only, and does not prove the
   superset for all code.

## CI callers and hooks (steps 3 and 6)

The known callers:

- **`astral-sh/ruff-action@v4`.** It has no diff filter. For option a, pass the
  changed files through `src`. Its `version:` must be the local version
  (`ruff --version`). When the team agrees that CI runs the strict file too:
  `args: check --config ruff.strict.toml`.
- **`reviewdog/action-ruff`** with `filter_mode: added`: option b in CI.
- **`astral-sh/ruff-pre-commit`.** Its hook checks the files of the commit, which is
  option a. Its `rev:` must be the local version. For the strict file:
  `args: [--config, ruff.strict.toml]`.

A CI step that runs ruff through a task runs the task: compare the task. A caller that
is not in this list: research it (the research reference).

For example, option a in GitHub Actions. The `run` shell stops at a failed command,
so a missing base ref fails the step. `src` splits the list at each space, so a path
with a space does not pass through it:

```yaml
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0
      - id: changed
        run: |
          base=$(git merge-base HEAD "origin/${{ github.base_ref }}")
          echo "files=$(git diff --name-only --diff-filter=d "$base" -- '*.py' | tr '\n' ' ')" >> "$GITHUB_OUTPUT"
      - uses: astral-sh/ruff-action@v4
        if: steps.changed.outputs.files != ''
        with:
          src: ${{ steps.changed.outputs.files }}
```
