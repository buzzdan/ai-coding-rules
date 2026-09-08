#!/usr/bin/env bash
# Scaffold the fixture with every //nolint directive stripped, so the linter
# goes red on the design plants and the lint-fixer's escalation routing is
# exercised. Same base commit shape as default.sh; the stripped state IS the
# committed state, so a Quickfix run's diff is only the agent's work.
#
# Usage: scaffold/red-lint.sh <dest-dir>
set -euo pipefail

dest="${1:?usage: red-lint.sh <dest-dir>}"
here=$(cd "$(dirname "$0")" && pwd)
fixture="$here/../fixtures/go-mini"

mkdir -p "$dest"
cp -R "$fixture/." "$dest/"
cd "$dest"
# Remove trailing //nolint[:linters] [// reason] from every Go line; the code
# itself is untouched. Whole-line directives (rare) are deleted.
find . -name '*.go' -not -path './.git/*' -print0 \
  | xargs -0 sed -i -E -e 's@[[:space:]]*//nolint(:[A-Za-z0-9_,-]+)?([[:space:]]*//.*)?$@@' -e '/^[[:space:]]*\/\/nolint/d'
git init -q
git -c user.name=fixture -c user.email=fixture@example.com add -A
git -c user.name=fixture -c user.email=fixture@example.com commit -q -m "go-mini: initial import (lint directives removed)"
remaining=$(grep -rn '//nolint' --include='*.go' . | wc -l)
echo "scaffolded go-mini (red-lint) at $dest ($(git rev-parse --short HEAD)); nolint directives remaining: $remaining"
