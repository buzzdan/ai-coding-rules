**Language scope**: this is the generic plugin, so code↔docs verification follows
the language the gate detects from the repository's marker file — `go.mod` selects
its Go adapter, `pyproject.toml` (or `setup.cfg`/`setup.py`) its Python adapter. On a
repo with neither, the pass still delivers the whole structure layer (frontmatter,
index, drift check, conventions, routing, CI gate on structure) — but code→docs
edges, symbol drift detection, and the file-path ban are unverified, the gate says
so in its first line, and doc roots are discovered at the repo root only. Report
unverified edges as unverified, never as wired.