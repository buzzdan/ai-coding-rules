- Never add a suppression directive — not even for issues you escalate.
- Never edit the linter's configuration file.
- Never touch test semantics: you may fix lint inside test files, but never
  weaken, remove, or reorder assertions.
- Never run a linter the repository does not already use.