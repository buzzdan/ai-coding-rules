# ESLint — the lint-setup reference

<!-- residue-exempt: this reference names ESLint, its plugins, its rules and its CI callers on purpose. -->

The lint-setup skill reads this file in the step that names it. It is for ESLint 9
with a flat config. Before you use a flag, make sure that the project's version has
it: `npx --no-install eslint --help`. `<tmp>` is a temporary directory outside the
repository, for example from `mktemp -d`. `<rec>` is the recommended config,
`<this skill dir>/../../setup/eslint.config.ldd.mjs`.

## The doctor's rows

The doctor runs the project's own ESLint with `--print-config` on one source file, so
the rows show the values on both sides.

Run ESLint as `npx --no-install eslint`, and only when the doctor checked ESLint for
this project (no `cannot verify` row). Without a local ESLint, plain `npx eslint`
downloads a package, which is an install; with `--no-install`, it fails.

## Count the findings (step 4)

ESLint takes a rule on the command line (`--rule`) on top of the project's own config.
The project's files and ignores thus stay as they are, and the count needs no
temporary config.

**Run A, every recommended value**, from the project root:

```sh
npx --no-install eslint --format json --output-file <tmp>/a.json \
  --rule 'max-params: [error, 4]' \
  --rule 'sonarjs/cognitive-complexity: [error, 15]' .
```

Put one `--rule` per rule of `<rec>`, with its value from `<rec>`. The example shows
two of them.

- A rule of a plugin counts only when the project has that plugin installed. When the
  project's config does not load the plugin, add `--plugin <name>`. When the plugin is
  not installed, say "cannot count: the plugin is not installed". Its install is a
  line of the plan.
- A rule that needs type information (several `@typescript-eslint` rules) counts only
  when the project's config gives the parser its TypeScript project. Else say "cannot
  count: the rule needs typed linting".
- A `--rule` applies to each file that ESLint checks, also where the project's config
  turns the rule off for some files. When the config has such an entry, tell the user
  that the count can be high.

**Run B, the project's own config:**
`npx --no-install eslint --format json --output-file <tmp>/b.json .`

**The count per rule:** `grep -o '"ruleId":"[^"]*"' <tmp>/a.json | sort | uniq -c`,
and the same for `<tmp>/b.json`.

**One more value, only when the user asks for it:** run A with that one `--rule`.

When the project has an `eslint-suppressions.json`, the counts must include the
suppressed findings: add `--suppressions-location <tmp>/none.json` (a path with no
file) to each run.

Before step 6, never use `--fix`, `--cache`, `--suppress-all`, `--suppress-rule` or
`--prune-suppressions`: each writes a file into the repository.

## New issues only (steps 3 and 5)

The forms a team may already use: an `eslint-suppressions.json` file (bulk
suppressions); `eslint-plugin-diff`; reviewdog with `filter_mode: added`; lint-staged,
which checks the files of the commit.

Ladder step 2, bulk suppressions (ESLint 9.24 or later):

- `npx --no-install eslint --suppress-all` writes `eslint-suppressions.json`: the
  findings of today. A later run fails only on a finding that the file does not hold.
- `npx --no-install eslint --prune-suppressions` removes the entries of fixed findings.
- The file lives in the repository, so CI and each teammate obey it with no other
  change. The `--suppress-all` run is an edit: it is a line of the plan, and it runs in
  step 6 after the config edits.

## The strict file (ladder step 3)

Name: `eslint.config.strict.mjs`, beside the original. It imports the original and
adds its entries after the entries of the original:

```js
import base from './eslint.config.mjs'

export default [
  ...base,
  {
    rules: {
      'max-params': ['error', 4],
      'sonarjs/cognitive-complexity': ['error', 15],
    },
  },
]
```

A strict entry only adds a rule or makes a limit stricter. It must not:

- turn a rule off;
- set a severity of `warn` for a rule that the original sets to `error`;
- have a `files` pattern that matches fewer files than the entry of the original that
  sets the same rule;
- have an `ignores` key;
- change `linterOptions`, `languageOptions`, `settings` or `plugins` of the original.

The task that runs it, as a `package.json` script:

```json
"lint:strict": "eslint --config eslint.config.strict.mjs"
```

A scope goes after `--`: `npm run lint:strict -- src/a.ts`. With no scope, ESLint
checks the whole project.

## The superset check (step 7)

**Check each run before you compare.** A run that fails, or a list that is not
there, compares nothing: `comm` then prints nothing, and that looks like a pass.
ESLint exits 1 when it reports a finding: that is a run that worked. When a run exits
with 2 (a config or a crash), or when `<tmp>/original.json` or `<tmp>/strict.json` is
not there, say "cannot check the superset", with the cause from stderr. Never say
that the superset holds.

1. **The rules:** for one source file of each kind (for example `.ts` and `.tsx`),
   run `npx --no-install eslint --config <original> --print-config <file>` and
   `npx --no-install eslint --config eslint.config.strict.mjs --print-config <file>`.
   Each rule that the original turns on must be on in the strict file, at the same
   option or a stricter one.
2. **The findings on the current tree:** run each config with
   `--format json --output-file <tmp>/<name>.json .`, and add
   `--suppressions-location <tmp>/none.json` when the project has a suppressions file.
   Each run must exit 0 or 1.
3. Make one line per finding, and sort:
   `node -e 'for (const f of require(process.argv[1])) for (const m of f.messages) console.log(f.filePath + ":" + m.line + ":" + m.column + " " + m.ruleId)' <tmp>/<name>.json | sort > <tmp>/<name>.sorted`.
4. `comm -23 <tmp>/original.sorted <tmp>/strict.sorted` must print nothing. Each line
   that it prints is a finding of the original that the strict file lets pass: show
   it, and correct the strict file.
5. Tell the user that this checks the current tree only, and does not prove the
   superset for all code.

## CI callers and hooks (steps 3 and 6)

The known callers:

- **A plain `npx eslint` step in CI.** It obeys the suppressions file. It reads another
  config only through `--config`: when the team agrees that CI runs the strict file
  too, the step runs the strict script.
- **`reviewdog/action-eslint`** with `filter_mode: added`: new lines only, in CI.

The ESLint version in CI comes from the lock file, the same as the local one, unless
the CI step installs another version: compare them. A CI step that runs ESLint
through a script or a task runs that script: compare the script. A hook (husky,
lint-staged) runs a script or a command: compare it the same way. A caller that is
not in this list: research it (the research reference).
