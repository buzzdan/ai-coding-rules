#!/usr/bin/env bash
# Test scaffold: a two-file Go module plus a .git dir that graders must skip.
set -euo pipefail
dest="$1"
mkdir -p "$dest/.git"
printf 'module x\n\ngo 1.24\n' > "$dest/go.mod"
printf 'package x\n\n// Answer is the answer.\nconst Answer = 42\n' > "$dest/x.go"
printf 'package x -- inside .git, must not be counted\n' > "$dest/.git/description"
echo "scaffolded $dest"
