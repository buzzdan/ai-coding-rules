#!/usr/bin/env bash
# Scaffold a tiny Python-only repository into <dest>: no go.mod, no .go files.
# The trigger-non-go case checks that "implement X" here does NOT start the
# go-ldd workflow.
#
# Usage: trigger-non-go/scaffold.sh <dest-dir>
set -euo pipefail

dest="${1:?usage: scaffold.sh <dest-dir>}"
mkdir -p "$dest/app"
cat > "$dest/pyproject.toml" <<'TOML'
[project]
name = "py-mini"
version = "0.1.0"
description = "A tiny HTTP service used as a non-Go eval fixture"
requires-python = ">=3.11"
dependencies = []

[tool.pytest.ini_options]
testpaths = ["tests"]
TOML
cat > "$dest/app/__init__.py" <<'PY'
PY
cat > "$dest/app/main.py" <<'PY'
"""py-mini: a minimal WSGI application serving /healthz."""

from wsgiref.simple_server import make_server


def application(environ, start_response):
    path = environ.get("PATH_INFO", "/")
    if path == "/healthz":
        start_response("200 OK", [("Content-Type", "text/plain")])
        return [b"ok"]
    start_response("404 Not Found", [("Content-Type", "text/plain")])
    return [b"not found"]


def main() -> None:
    with make_server("", 8080, application) as server:
        server.serve_forever()


if __name__ == "__main__":
    main()
PY
cat > "$dest/README.md" <<'MD'
# py-mini

A minimal WSGI service.

- `python -m app.main` — serve on :8080
- `python -m pytest` — run the tests
MD
cd "$dest"
git init -q
git -c user.name=fixture -c user.email=fixture@example.com add -A
git -c user.name=fixture -c user.email=fixture@example.com commit -q -m "py-mini: initial import"
echo "scaffolded py-mini at $dest ($(git rev-parse --short HEAD))"
