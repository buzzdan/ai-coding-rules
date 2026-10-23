---
name: lint-setup
description: |
  Compares the linter setup of this repository with the LDD recommended setup, and agrees a tighter setup with the user before any edit. Applies to the languages that no installed language-specific linter-driven-development plugin covers.
  WHEN: the user asks to compare, align or set up the linter config with the LDD recommended setup, or runs /ldd-setup.
  Shows, per rule, the recommended value, the project's value and the finding count at each; the user decides per rule; files change only after the user agrees to the edit plan. Not for fixing lint findings.
allowed-tools:
  # residue-exempt: the check commands of the linters that the plugins ship recommended configs for.
  - Read
  - Grep
  - Glob
  - WebSearch
  - WebFetch
  - Bash(bash *ldd-lint.sh *)
  - Bash(git *)
  - Bash(golangci-lint run *)
  - Bash(golangci-lint linters *)
  - Bash(golangci-lint config *)
  - Bash(ruff check *)
  - Bash(npx eslint *)
  - Bash(reviewdog *)
---

<objective>
Compare the linter setup of each project with the recommended setup of this plugin.
Agree a tighter setup with the user. Then make only the agreed edits. This skill is a
conversation with the user, not a report. The user may not know linter internals:
say each finding in plain words.

The twelve rules do not change. A value the user relaxes changes the linter only;
the review keeps the limits of the rules.
</objective>

<promise>
**Follow these steps in this order, and edit nothing before step 6.**

- An edit is any change to a file in the repository: a linter config, a task file, a
  CI workflow, a hook config, a suppressions file, `.ldd-lint.yaml`. A temporary file
  outside the repository is not an edit.
- `allowed-tools` lets you read, search, run the doctor, run `git` and run the check
  commands of the linters with no prompt. Edit, Write, installs and all other Bash
  calls ask the user first. A linter run with a fix flag, or a run that writes a file,
  still matches a check-command pattern. Thus this text also guards the edits. In an
  auto permission mode, no call asks the user: only this text guards the edits.
- Before step 6, do not run a linter with a fix flag. A fix setting in a config (for
  example `fix = true` or `issues.fix: true`) counts as a fix flag: turn it off on the
  command line, as the linter reference shows. Do not run a command that writes
  a suppressions file or a baseline file into the repository. Do not run `git add`,
  `git commit`, `git checkout`, `git stash`, `git reset` or `git clean`. Do not
  install a package.
- **Headless:** when no user turn can come after step 5 (a headless run, or a run as
  a subagent), print the table of step 5 and the plan of step 6, and stop. Edit
  nothing.
</promise>

<paths>
- The script: `<this skill dir>/../../scripts/ldd-lint.sh`. Call it as one direct
  command, for example
  `bash <this skill dir>/../../scripts/ldd-lint.sh doctor --root <dir> --tsv`.
  Do not put a variable, a `cd` or a pipe around it: the allowed pattern then does
  not match, and each call asks the user.
- The recommended configs: `<this skill dir>/../../setup/`.
- The linter reference: `<this skill dir>/<linter>.md`, where `<linter>` is column 2
  of the doctor's rows. It holds the recipes per linter: the counts, the "new issues
  only" setup, the strict file, the superset check, the CI callers and the hooks.
  Read it when a step names it.
- The research reference: `<this skill dir>/research.md`. Read it only when a step
  below sends you there.
</paths>

## 1. Find the projects

1. Arguments name the projects: one directory each. With no argument, use one project
   per linter config root. In a monorepo, pick the projects from context: the
   directories that hold a linter config and source files, the request of the user,
   and the files the user works on.
2. Tell the user the projects you picked, and why.
3. Read the record of each project first: `.ldd-lint.yaml` in the project root, if it
   exists. A rule in its `agreed:` list is a decision the team made. Do not ask about
   it again, unless step 2 shows drift for it.

## 2. Check the setup of each project

1. Run the doctor once per project:
   `bash <this skill dir>/../../scripts/ldd-lint.sh doctor --root <dir> --tsv`.
   Each row on stdout is: language, linter, rule, state, recommended, current,
   source. A `doctor:` line on stderr is a note.
2. Branch on the exit code:
   - **0:** the doctor checked the project. Continue.
   - **2:** read the stderr line.
     - `no language in scope has a recommended linter config`: read the research
       reference, and do the research for this project.
     - `no source file in scope`: tell the user. Stop for this project. No research.
     - `.ldd-lint.yaml: <key> must be a positive integer` or
       `.ldd-lint.yaml: package_warn_files (…) must be below package_max_files`: the
       record has a bad value. Quote the line, name the key and the fix, and stop for
       this project. Do not edit the record before step 6.
     - `no recommended configs at <dir>`: the plugin install is broken. Quote the
       line, tell the user to reinstall the plugin, and stop.
     - Any other line is a wrong call of the script: an argument it does not take, or
       a path that does not exist. Correct the call once. When the same line comes
       back, quote it and stop for this project.
   - **3:** another installed plugin checks every language of this project. Show the
     doctor's line `doctor: <language> — <plugin> is installed and checks this
     language; run /<prefix>-setup`, and tell the user to run that command. Stop for
     this project. No research.
3. Show each `doctor: <language> — …` note to the user in plain words.
4. **`cannot verify` stops that project only.** A row whose state starts with
   `cannot verify:` means that the doctor cannot check the setup. Do not work around
   it. Stop for this project. Name the cause from the row and the fix, and continue
   with the other projects:
   - the linter is not installed: name the install command that the project uses (its
     lock file, its tool list or its README). Do not install it.
   - the config does not load (the linter rejects the config, or cannot run with it):
     quote the message of the linter, and name the file and the key.
   - the config fails the linter's own check: quote the message, and name the key.
   - the agreed config does not exist: the `lint_config` item of the record names a
     file that is gone. The fix: restore the file, or remove that item and run the
     setup again.
   - the linter is installed in a project below, not here: this is not a broken
     setup. Run the doctor with `--root` on that project, and add it to the projects.
5. Find the drift. An agreed rule shows drift when its `current` ends in
   `; agreed: <value>` (the setting changed), or when stderr says
   `doctor: <path> changed since the setup was agreed` for a config of its linter.
   When the linter reference has a drift step, do it now. Ask about these rules again
   in step 5.
6. A stderr line `doctor: .ldd-lint.yaml: no row for <linter> <rule>; the line is
   ignored` names a record line for a rule that the doctor does not check: a typo, or
   a rule that the recommended config does not have now. Show it, and ask in step 5
   whether to remove the line.

## 3. Find what the team already has

1. Read the task file of the project: a Taskfile, a Makefile, the `scripts` of
   `package.json`, a `justfile`, or the file that the project uses. Read the CI
   workflows and the hook config (for example lefthook, pre-commit, husky,
   lint-staged).
2. **Find each task by the command it runs, not by its name.** Find the lint task and
   the lint-fix task: a task that runs the linter with a fix flag is the lint-fix
   task, whatever its name. A task named `lint` can be the fix task.
3. Find a "new issues only" setup that the team already uses, and the base branch it
   uses. The linter reference names the forms. Tell the user "you already have this",
   and keep it.
4. Find the base branch: the branch the team merges into. Read it from the CI
   triggers, from an existing "new issues only" setting, or from
   `git symbolic-ref refs/remotes/origin/HEAD`. It is not always `main`.
5. Find each CI step and each hook that runs the linter. Compare it with the known
   callers in the linter reference. For a caller that is not in that list, read the
   research reference, and do the research for that caller.

## 4. Count the findings

1. **Say the time cost first.** Before the first run, tell the user how long one run
   takes on this project, and that the count needs two runs per linter. Use the
   duration of the lint job in CI when you can see it, else the number of source
   files (`git ls-files`).
2. **Do two runs per linter** with the recipe in the linter reference:
   - run A: every recommended value;
   - run B: the project's own config.

   Both runs check the whole project, with no "new issues only" filter.
3. **Put temporary configs outside the repository**, in a temporary directory. The
   paths and the exclusions in a temporary config must still resolve to the same
   files as in the original config.
4. Count the findings per rule in each run. When a run cannot count a rule (for
   example, a linter plugin is not installed), say "cannot count" and why.
5. A run for one more value happens only when the user asks for that value.

## 5. Agree, per project, in one table

1. **Show one table per project.** One row per rule that needs a decision: a rule that
   is not agreed and is in the state `missing`, `limit looser`, `options differ` or
   `named`; and each agreed rule with drift (a drift row), whatever its state. A drift
   row also shows the value the team agreed and the value now. Say each row in plain
   words: what the rule limits, the
   project's value, the recommended value, and the finding count at each. For
   example: "Function complexity — your limit: 10; recommended: 8; 214 functions fail
   at 8; 31 at 10." When a value is `see <file>: <key>`, read the value at that
   place. A key that is not there means the linter's default.
2. **Give a default choice per row.** The choices are:
   - `recommended`: take the recommended value;
   - `keep`: keep the project's value;
   - `<value>`: use another value;
   - `off`: leave the rule off;
   - `org`: the organization owns this value;
   - on a drift row only, `accept`: agree the value that the config holds now. `keep`
     on a drift row restores the agreed value in the config, and its record line
     stays.

   The default is `accept` for a drift row, and `recommended` for each other row. A
   rule in the state `runs`, `limit stricter` or `agreed` with no drift needs no row:
   list those rules in one line under the table.
3. The user answers the exceptions by rule in one reply, for example "all defaults;
   complexity keep; arguments org". Ask for a short reason for each `keep`,
   `<value>`, `off` and `org`: the record keeps it.
4. **Propose a ladder step from the counts:**
   1. Tighten the original config. One config for everybody. Propose it when the
      findings at the agreed values are few, or the team accepts a cleanup.
   2. Tighten the original config, and check new issues only. Still one config: the
      old findings stay until a change touches that code. Propose it when the
      findings are many. The linter reference gives the form, the base branch it
      needs and its cost.
   3. A strict file that only LDD uses: `<the linter's file>.strict.<ext>`. **Never
      recommend step 3 from the counts.** Ask whether the team accepts changes to the
      shared config, and offer step 3 only when it does not. **Step 3 is the strict
      file and a task that runs it, as one agreement.** Without the task, the
      lint-fixer does not find the file, so never offer the file alone.

   The per-rule choices apply in each step.
5. Headless: print the tables and the plan of step 6 with the default choices, and
   stop.

## 6. Show the edit plan, then edit

1. **Show the full plan as one diff per file**: the linter configs, the tasks, the CI
   and hook edits, the installs, and the record. Change no file that is not in the
   plan.
2. Tasks: **never rename a task, and never change what an existing task does.** Add a
   task only where no task runs the linter in the agreed way. Give it a name that fits
   the names in the file. A task that you add accepts a scope: a Taskfile through
   `{{.CLI_ARGS}}` (`task <name> -- ./pkg/a ./pkg/b`), a Makefile through
   `ARGS`. With no scope, it checks all that the agreed mode allows.
3. CI: keep a native action; do not replace it with a task. Where a caller does not
   agree with the agreed setup, show the edit. The linter reference names the cases.
4. **Hooks: name each hook that runs a lint task, with what changes for each
   teammate's commit.** For example: "lefthook runs `task lint` on each commit; from
   now on, a commit fails on a new complexity finding in the files it changes."
5. An install (a linter, a linter plugin, a helper tool) is a line in the plan. Do the
   install only when the user agrees to that line.
6. The record: show the keys and one line per decision. The fingerprint lines come
   from the edited files, so the plan says "written after the edits" for them.
7. **Edit only after an explicit yes to this plan.** A question or a change request is
   not a yes: show the changed plan and ask again.
8. After the yes, edit in this order:
   1. The linter configs, the tasks, the CI and the hooks, and the agreed installs.
   2. One record line per decision, from the script:
      `bash <this skill dir>/../../scripts/ldd-lint.sh agree --root <dir> --linter <linter> --rule <rule> --decision <d> --reason '<reason>'`.
      Put the reason in single quotes, and write each apostrophe in it as `'\''`, so
      that the shell does not change the text.
      Use `--decision current` for `keep`, for `accept` and for `<value>` (after the
      config holds that value), `off` for `off`, and `org` for `org`. A rule in the
      state `missing` has no setting: use `off`. A `recommended` choice needs no line;
      on a drift row, it removes the old line. `keep` on a drift row keeps the old
      line. With a new
      strict file (the record has no `lint_config` item for it yet), add
      `--config <strict file>`, relative to the project root.
   3. The fingerprint lines, after the last config edit:
      `bash <this skill dir>/../../scripts/ldd-lint.sh agree --root <dir> --fingerprint`,
      with `--config <strict file>` when the strict file is new.
   4. With a strict file, its line:
      `bash <this skill dir>/../../scripts/ldd-lint.sh agree --root <dir> --lint-config <linter> <strict file>`.
   5. **Write the record last.** Copy each line that `agree` printed unchanged, under
      its key: `agreed:`, `lint_config:` or `lint_fingerprint:`. With no `agreed`
      line, write `agreed: []`. Write only the key lines and the copied lines. Keep
      the other keys of the file (for example `file_max_lines`). Keep the line of
      each agreed rule that this run did not ask about, and replace the line of each
      rule that the user decided again. Replace the fingerprint lines of the linters
      that this run checked. Keep the items of a linter that this plugin does not
      report: another plugin owns them.
9. `agree` changes each ` | ` in a reason to ` / `. When a printed line is not the
   line in the plan, show the difference before you write the record.

The record, for example:

```yaml
lint_config:
  - "<linter> <strict file>"
lint_fingerprint:
  - "<linter> <config file> <hash>"
agreed:
  - "<linter> <rule> = <value> | <reason>"
```

## 7. Verify

1. Run the doctor again on each project that you edited.
2. Each row of an agreed rule must show `runs` or `agreed`, and stderr must have no
   `changed since the setup was agreed` line. Else name the row that does not, and
   why.
3. With a strict file, do the superset check of the linter reference. Say that it
   checks the current tree only, and does not prove the superset for all code.
4. Tell the user what changed, file by file, and the findings that remain at the
   agreed values. To fix them, the user can run `/ldd-quickfix`.
