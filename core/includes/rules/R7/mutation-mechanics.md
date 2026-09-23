- **Mutation mechanics**: the repository's mutation testing tool, configured once
  and pointed at leaf packages only; run it after the leaf's tests are green and
  after each fix that kills a survivor; a threshold in CI, where the repository has
  one, is set per leaf package, never module-wide.
