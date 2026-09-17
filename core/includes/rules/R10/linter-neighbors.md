- **The linter owns the mechanical neighbors.** Ignored errors, unclosed resources,
  copied locks — enforce these in the repository's linter configuration where its
  linter has the checks; do not re-hunt them here.