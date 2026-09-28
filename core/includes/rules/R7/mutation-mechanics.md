- **Mutation mechanics**: the repository's mutation testing tool, configured once
  and pointed at leaf packages only; run it after the leaf's tests are green and
  after each fix that kills a survivor; a threshold in CI, where the repository has
  one, is set per leaf package, never module-wide. The tool is installed the way the
  repository installs its other tools: when it is not on the machine, propose a
  target in the task runner the repository already has (Taskfile, Makefile) that
  installs a pinned version and runs it over one leaf package, and where there is no
  task runner propose the local install command for the developer to run; ask before
  installing, never install silently, and never read a run that did not execute as a
  pass. When the language has no maintained mutation tool, the check is done by hand and stays cheap because a
  leaf is small: for every comparison in the leaf the table holds a row at the
  boundary value and one just past it, for every boolean condition a row on each
  side, and a suspected gap is confirmed by flipping the operator, running the
  leaf's tests, and putting it back — green tests mean a survivor.
