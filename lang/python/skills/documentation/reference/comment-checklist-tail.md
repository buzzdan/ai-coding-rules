- [ ] Every docstring fits its tier budget — helper 0–1 / contract 2–3 /
      crossroads ≤5 prose lines (R9's tiered comment policy); `Args:`, `Returns:`
      and `Raises:` sections are the contract's shape and are free; overflow moved
      to the feature doc, the package's `__init__.py` docstring (~20–30 lines) used
      for package docs that earn it
- [ ] Menu sections included only where they earn their place for that symbol,
      within the tier budget
- [ ] Crossroads that deserve a richer inline docstring got an expand
      recommendation in the report — never extra lines beyond budget
- [ ] `See docs/<feature>.md` edge present wherever a feature doc exists — on its
      own trailing line of the docstring, never woven into the summary line
- [ ] Doctests: at least one `>>>` example per complex/core type; runnable under
      `pytest --doctest-modules` (or the repository's doctest runner); happy path
      only; the expected output on the line below
