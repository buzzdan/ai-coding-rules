- **Mutation mechanics**: `mutmut run` with `[tool.mutmut]` in `pyproject.toml` listing
  the leaf packages under `paths_to_mutate` — never the whole `src/` tree — after the
  leaf's tests are green there and after each fix; `mutmut results` lists the
  survivors to triage and `mutmut show <id>` prints one mutant's diff. Mutation runs
  reuse the repository's pytest, never a second runner.
