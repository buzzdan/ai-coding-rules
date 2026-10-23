# Research — the lint-setup reference

The lint-setup skill reads this file only when a step sends it here. Research finds
the community practice for a language, a linter or a CI caller that the plugin does
not know, and names the source of each recommendation.

## When to research

Research starts only from one of these signals:

- the doctor exits 2 with the stderr line
  `doctor: no language in scope has a recommended linter config`;
- a CI step or a hook that runs the linter is not in the known callers of the linter
  reference.

These are not signals: a doctor exit 3 (another installed plugin checks the language:
name its command), a `no source file in scope` line, and a doctor note on an exit 0.
Show a note to the user, and do no research for it.

## Without WebSearch

When this session has no WebSearch tool, tell the user: "I cannot search online in
this session, so I recommend nothing for <the language, linter or caller>." Recommend
nothing for it. Continue with the other projects and rules.

## The queries

- **A query holds public tool names only:** the language, the linter, the CI system,
  the action or the hook, and a version. For example
  `"<linter> max complexity setting"` or `"<action> only new issues"`.
- Never put repository content in a query: no file name, path, code, config value,
  project name, organization name or repository URL.

## What to find

For a language or a linter, find the rules that hold the limits of the twelve rules.
The recommended configs under `<this skill dir>/../../setup/` show what to look for:
the complexity, length, nesting, argument and file-length limits, and the rules about
globals, mutation and exhaustive dispatch. For each rule, find:

- the linter and the rule that hold it, and the config file and key;
- the value that the community uses, and the limit of the twelve rules;
- the command that checks a config, and the command that counts the findings;
- the "new issues only" forms of that linter, if any.

For a CI caller, find: the config it reads, how it sets the version, and whether it
filters to new issues only.

## The sources

- Fetch each source with WebFetch. **Each recommendation shows the URL that this
  session fetched.** Do not give a URL from memory, or a search result that you did
  not open.
- Use the docs of the linter or of the action first, then its repository README. Use
  other sources only when the docs do not say it, and say so.

## What follows

Continue with steps 3 to 7 of the skill, with the researched setup in place of the
recommended config. Each row of the table in step 5 shows its URL. The doctor has no
rows for a linter that the plugin does not know, so `agree` prints no record line for
it. Do not write record lines by hand.
