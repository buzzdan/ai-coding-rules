#!/usr/bin/env bash
# Documentation conformance for this repo: runs the Go plugin's own repo-brain
# gate over the files git tracks (plus untracked files that are not ignored).
# Ignored paths never reach the gate, so a local evals clone under .evals/ or
# the eval suite a run copies under go-linter-driven-development/evals/ cannot
# change the result. Anything the gate reports is a real violation in this
# repo's docs.
#
# Usage: bash scripts/check-docs.sh [--fix]
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
gate="$root/go-linter-driven-development/scripts/check-repo-brain.sh"
view=$(mktemp -d "${TMPDIR:-/tmp}/check-docs.XXXXXX") || exit 2
trap 'rm -rf "$view"' EXIT
git -C "$root" ls-files -z -co --exclude-standard | rsync -a -0 --files-from=- "$root/" "$view/" || exit 2

out=$(cd "$view" && bash "$gate" "$@" . 2>&1)
status=$?
if [[ "$*" == *--fix* ]]; then
  # --fix rewrites index lines inside the view; copy the rewritten docs back.
  rsync -a --existing --include='*/' --include='*.md' --exclude='*' "$view/" "$root/"
fi
real=$(printf '%s\n' "$out" | grep -E '^[[:space:]]*\[Q[0-9]+\]' || true)
if [[ -n "$real" ]]; then
  printf '%s\n' "$real"
  echo "check-docs: $(printf '%s\n' "$real" | wc -l | tr -d ' ') violation(s) — rules: docs/conventions.md"
  exit 1
fi
if [[ $status -ne 0 ]]; then
  printf '%s\n' "$out" | tail -n 5
  echo "check-docs: gate exited $status"
  exit "$status"
fi
echo "check-docs: OK"
