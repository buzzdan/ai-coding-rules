### H1 — A suppression is a review finding, not a tool

A `{{.Nolint}}` directive is never added on your own: fix the code, and when the
finding is a true false positive, propose the exclusion in the linter's configuration
and get it reviewed. A new suppression in a diff is itself a finding, and no automated
lint-fix pass adds one or edits the configuration.
