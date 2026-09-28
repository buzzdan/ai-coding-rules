- **Mutation mechanics**: `mutmut run` with `[tool.mutmut]` in `pyproject.toml` listing
  the leaf packages under `paths_to_mutate` — never the whole `src/` tree — after the
  leaf's tests are green there and after each fix; `mutmut results` lists the
  survivors to triage and `mutmut show <id>` prints one mutant's diff. Mutation runs
  reuse the repository's pytest, never a second runner. When `mutmut` is not
  installed, propose adding it to the dev dependency group `pyproject.toml` already
  uses (`uv add --dev mutmut`, or the project's equivalent) and a `mutate` target
  beside `test` and `lint` in the repository's Taskfile or Makefile that runs
  `mutmut run && mutmut results`; with no task runner and no dev group, propose
  `pipx install mutmut` for the developer to run. Ask first, never install silently,
  and never read a run that did not execute as a clean one.
