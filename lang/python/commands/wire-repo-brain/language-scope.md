**Language scope**: this is the Python plugin, so code↔docs verification is
Python-first. On a repo with no Python, the pass still delivers the whole structure
layer (frontmatter, index, drift check, conventions, routing, CI gate on
structure) — but code→docs edges, symbol drift detection, and the file-path ban
only cover `.py` files, and doc roots are only discovered at the repo root and
`pyproject.toml` sub-projects (a Go or TypeScript sub-project's own docs/ is not
wired — it is reported, not silently skipped). Non-Python symbols cited in covered
docs still resolve via the gate's whole-word fallback.
