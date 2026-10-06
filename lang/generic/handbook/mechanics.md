| Discovery | the test, lint and lint-fix commands are the ones the repository defines in its README, CLAUDE.md, Taskfile, Makefile, package scripts or CI; none found is a finding, not a guess |
| Suppression forms | `# noqa`, `eslint-disable`, `#[allow(...)]`, `@SuppressWarnings`, a `nolint` comment: one rule for all of them, see H1 |
| Examples | pseudocode: `fail` is the language's failure form, `absent` its declared absence, `spawn` and `join` its concurrency primitives, `hidden` its private visibility |
| Tests | beside the code or under a `tests/` tree, whichever the repository does; every table row named; the package imported as a consumer would |
