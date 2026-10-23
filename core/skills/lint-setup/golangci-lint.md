# golangci-lint — the lint-setup reference

<!-- residue-exempt: this reference names golangci-lint, its linters, its CI action and its hooks on purpose. -->

The lint-setup skill reads this file in the step that names it. It is for
golangci-lint v2. Before you use a flag, make sure that the installed version has it:
`golangci-lint run --help`. `<tmp>` is a temporary directory outside the repository,
for example from `mktemp -d`. `<rec>` is the recommended config,
`<this skill dir>/../../setup/golangci.yaml`.

## The doctor's rows

golangci-lint reports which linters run, not their settings. Thus `recommended` and
`current` are `see <file>: <key>` on both sides. Read the value at that place. A key
that is not there means the default of that linter: the reference file of
golangci-lint lists each default
(https://github.com/golangci/golangci-lint/blob/main/.golangci.reference.yml).

A `revive <rule>` row comes from a presence check: the doctor found the rule name in
the config. Its value is the `arguments` of the entry with `name: <rule>` under
`linters.settings.revive.rules`.

**Compare the two values yourself (step 5).** The doctor gives a rule that runs the
state `runs` at any value. For each row whose `recommended` is `see <rec>: <key>`:

1. Read each setting under `<key>` in `<rec>`.
2. Read the same settings at the place that `current` names. A setting that is not
   there has the default of that linter. When `current` is `the linter's default`,
   use the defaults. When `current` starts with `<other> runs in its place`, read
   the setting of `<other>` that holds the same limit (for `cyclop`:
   `max-complexity`).
3. Compare each setting. A larger number lets more code pass for `min-complexity`,
   `lines`, `statements`, `threshold`, `min-len` and `min-occurrences`. For
   `maintidx` `under`, a smaller number lets more code pass. For a boolean or a list,
   find which value lets more code pass; when you are not sure, give the rule a row.
4. The project's value lets more code pass: the rule gets a row. The values are
   equal, or the project's value is stricter: the rule gets no row.

**The version of the linter.** The `doctor:` note names the golangci-lint binary that
the doctor ran (the one on PATH) and its version. Compare the version with each
version that the project pins: the `version:` of golangci-lint-action in CI, a binary
in the project (for example `.bin/golangci-lint-v2.4.0`), a tool entry in `go.mod`,
or a version in the task file. When they differ, tell the user that the rows come
from the version on PATH, and that the pinned version can enable other linters.

## Count the findings (step 4)

**Run A, every recommended value:**

1. Copy the project's config to `<tmp>/a.yaml`. With no project config, copy `<rec>`.
2. In the copy:
   - enable each linter of `<rec>` that the copy does not enable, and add each revive
     rule of `<rec>`;
   - set each setting of `<rec>` to its value in `<rec>`;
   - remove `issues.new`, `issues.new-from-rev`, `issues.new-from-merge-base` and
     `issues.new-from-patch`, so that the count covers the whole project;
   - remove `issues.fix`: with `issues.fix: true`, a run edits the source files;
   - set `run.relative-path-mode: gitroot`, and write each relative path of the copy
     (an exclusion `path`, a `paths` item, a file that a setting names) from the git
     root. Each path must resolve to the same files as in the original.
3. Check the copy: `golangci-lint config verify -c <tmp>/a.yaml`.
4. From the project root:
   `golangci-lint run -c <tmp>/a.yaml --fix=false --max-issues-per-linter 0 --max-same-issues 0 --issues-exit-code 0 --output.text.path <tmp>/a.txt ./...`
5. The count per linter is in the statistics at the end of stdout, for example
   `* gocognit: 214`. For a revive rule, count the lines of `<tmp>/a.txt` whose
   message starts with the rule name, for example `argument-limit:`.

**Run B, the project's own config:** the same command with `-c <the project's config>`.
When the config has an `issues.new*` key or `issues.fix`, use a copy without them,
made as in run A. Never run golangci-lint before step 6 without `--fix=false`.

**One more value, only when the user asks for it:** a copy of `<tmp>/a.yaml` with that
value, run with `--enable-only <linter>`.

Two limits stop a count early by default: 50 issues per linter and 3 issues with the
same text. Both flags above turn them off. Never count without them.

## New issues only (steps 3 and 5)

The forms a team may already use: `issues.new-from-merge-base`, `issues.new-from-rev`
or `issues.new: true` in the config; `--new-from-merge-base`, `--new-from-rev` or
`--new` on a command line; `only-new-issues: true` in golangci-lint-action.

Ladder step 2: `issues.new-from-merge-base: <base>` in the config.

- `<base>` is the branch the team merges into. Use a ref that exists both in a local
  clone and in CI, usually `origin/<base>`.
- `<rec>` holds `issues.new-from-merge-base: main`. When the plan copies `<rec>` into
  a project, set the value to the team's `<base>` for ladder step 2, and remove the
  key for ladder step 1.
- The cost: the CI checkout needs the history of the base branch, so it needs
  `fetch-depth: 0`. Tell the user that this fetches the full history, and the full
  history of each submodule too when the checkout fetches submodules.

## The strict file (ladder step 3)

Name: `.golangci.strict.yaml`, beside the original. golangci-lint v2 has no
`extends`: the strict file is a full copy of the original plus the changes. A change
only enables a linter or a revive rule, or makes a setting stricter.

The strict file must not have:

- a linter or a revive rule that the original enables and the strict file does not;
- a `linters.default` set that is smaller than the one of the original;
- a looser setting;
- a new exclusion: an item of `linters.exclusions.rules` or
  `linters.exclusions.paths`, a new item of `linters.exclusions.presets`, or a looser
  `linters.exclusions.generated`;
- `run.tests: false` when the original lints tests, or other `run.build-tags`;
- an `issues.new*` key that the original does not have;
- `issues.fix: true`: the task that runs the strict file then edits the source files.

When the original runs revive with its default rules (no `rules` list), a `rules` list
in the strict file turns those default rules off. Keep them on: set
`enable-default-rules: true` under `linters.settings.revive`, and check the file with
`golangci-lint config verify`.

The task that runs it, in a Taskfile:

```yaml
  lint-strict:
    desc: golangci-lint with the strict config; packages after -- narrow the run
    cmds:
      - golangci-lint run --config .golangci.strict.yaml {{"{{"}}.CLI_ARGS}}
```

In a Makefile:

```make
ARGS ?= ./...
lint-strict:
	golangci-lint run --config .golangci.strict.yaml $(ARGS)
```

The strict file does not follow a later change of the original. When the doctor says
that the original changed since the setup was agreed, propose the same change in the
strict file, and do the superset check again.

## The superset check (step 7)

1. **The enabled linters:** run `golangci-lint linters -c <original>` and
   `golangci-lint linters -c .golangci.strict.yaml`. Each linter in the enabled list
   of the original must be in the enabled list of the strict file.
2. **The findings on the current tree:** make a copy of each file with no `issues.new*`
   key and no `issues.fix`, as in run A. Run each copy from the project root with
   `--fix=false --max-issues-per-linter 0 --max-same-issues 0 --issues-exit-code 0 --show-stats=false --output.text.path /dev/null --output.tab.colors=false --output.tab.path <tmp>/<name>.tab ./...`.
3. Keep the place and the linter of each finding, and sort:
   `awk '{print $1, $2}' <tmp>/<name>.tab | sort > <tmp>/<name>.sorted`. The message
   holds the limit (`is high (> 3)`, `(> 2)`), so a stricter limit changes it: compare
   the place and the linter only.
4. `comm -23 <tmp>/original.sorted <tmp>/strict.sorted` must print nothing. Each line
   that it prints is a finding of the original that the strict file lets pass: show
   it, and correct the strict file.
5. Tell the user that this checks the current tree only, and does not prove the
   superset for all code.

## The drift step (step 2)

The doctor never sees a golangci-lint value, so drift shows only through the
fingerprint: the stderr line `doctor: <path> changed since the setup was agreed`.
When the doctor prints it for a golangci-lint config:

1. Find the commit that wrote the record: `git log -1 --format=%H -- .ldd-lint.yaml`,
   run in the project root.
2. Show what changed in the config since then: `git diff <commit> -- <path>`.
3. For each agreed golangci-lint rule (a record line
   `golangci-lint <rule> = see <file>: <key> | <reason>`), read the value now at that
   place. When the diff changed it, the rule shows drift: ask about it again in step 5.
4. With a strict file, do the superset check again.

In step 6, put the value that you read into the reason of each `keep` line, for
example `keeps min-complexity 20: the team cleans up first`. A later run can then show
the old value beside the new one.

## CI callers and hooks (steps 3 and 6)

The known callers:

- **`golangci/golangci-lint-action@v9`.** Compare and propose an edit when:
  - its `version:` is not the local version (`golangci-lint version`);
  - it reads another config than the agreed one. When the team agrees that CI runs
    the strict file too: `args: --config=.golangci.strict.yaml`;
  - the config has `issues.new-from-merge-base`, and the checkout step has no
    `fetch-depth: 0`;
  - it sets `only-new-issues: true` beside `issues.new-from-merge-base` in the config.
    The action's API-diff mode can pass where a local run fails. Prefer the ratchet
    of the config: propose to remove `only-new-issues`.
- **The pre-commit hooks of golangci-lint** (`repo: https://github.com/golangci/golangci-lint`,
  the hooks `golangci-lint`, `golangci-lint-full` and `golangci-lint-config-verify`).
  The hook takes the config through `args`, the same as the action.

A CI step that runs golangci-lint through a task runs the task: compare the task.
A caller that is not in this list: research it (the research reference).

For example, the CI steps of a project with the ratchet and a strict file that CI
runs too:

```yaml
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0
      - uses: golangci/golangci-lint-action@v9
        with:
          version: v2.8.0
          args: --config=.golangci.strict.yaml
```
