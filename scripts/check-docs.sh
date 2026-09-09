#!/usr/bin/env bash
# Documentation conformance for this repo: runs the Go plugin's own repo-brain
# gate over the repository and drops the lines about the eval fixture, whose
# documentation violations are planted on purpose (they are what the evals
# measure). Anything that remains is a real violation in this repo's docs.
#
# Usage: bash scripts/check-docs.sh [--fix]
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
gate="$root/go-linter-driven-development/scripts/check-repo-brain.sh"
fixture='go-linter-driven-development/evals/fixtures/'
out=$(cd "$root" && bash "$gate" "$@" . 2>&1)
status=$?
real=$(printf '%s\n' "$out" | grep -E '^\s*\[Q[0-9]+\]' | grep -v -F "$fixture" || true)
if [[ -n "$real" ]]; then
  printf '%s\n' "$real"
  echo "check-docs: $(printf '%s\n' "$real" | wc -l | tr -d ' ') violation(s) outside the eval fixture — rules: docs/conventions.md"
  exit 1
fi
if [[ $status -eq 2 ]]; then printf '%s\n' "$out" | tail -n 3; echo "check-docs: gate scanner failure"; exit 2; fi
echo "check-docs: OK (fixture plants ignored: $(printf '%s\n' "$out" | grep -c -F "$fixture"))"
