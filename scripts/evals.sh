#!/usr/bin/env bash
# evals.sh — run the behavioral evals against this checkout's Go plugin.
#
# The evals live in buzzdan/ldd-evals. This script shallow-clones that
# repository into .evals/ (ignored) or pulls it, then hands off to its
# Taskfile with PLUGIN set to this checkout's plugin directory. Every run
# spends real money; the Taskfile pins the model and sets a cost cap.
#
# Usage: bash scripts/evals.sh [TIER=cheap] [CAP=1] [CASE='trigger-*'] [MODEL=...] [OUT=...]
#   e.g. bash scripts/evals.sh TIER=cheap CAP=1 CASE='trigger-*'     # smoke, cents
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
repo=https://github.com/buzzdan/ldd-evals.git
if [[ -d "$root/.evals/.git" ]]; then
  git -C "$root/.evals" pull -q --ff-only
else
  git clone -q --depth 1 "$repo" "$root/.evals"
fi
# The clone sits under this repository's go.work, which would otherwise stop
# the runner's own module from building.
exec env GOWORK=off task -d "$root/.evals" go:run PLUGIN="$root/go-linter-driven-development" "$@"
