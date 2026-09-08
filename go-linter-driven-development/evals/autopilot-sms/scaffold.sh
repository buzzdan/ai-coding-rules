#!/usr/bin/env bash
# Case-local scaffold for autopilot-sms: the default go-mini scaffold plus the
# product spec at the repo root, amended INTO the base commit so the agent sees
# SPEC.md as part of the repository it was handed (not as an uncommitted file),
# and so every git-history check in postcheck.sh measures only the agent's work.
#
# Also sets a local git identity: the case pre-approves the SHIP step, so the
# agent commits its own prep and feature work and needs an author to do it.
#
# Usage: autopilot-sms/scaffold.sh <dest-dir>   (the runner calls it with cwd = this dir)
set -euo pipefail

dest="${1:?usage: scaffold.sh <dest-dir>}"
here=$(cd "$(dirname "$0")" && pwd)

"$here/../scaffold/default.sh" "$dest"

cp "$here/SPEC.md" "$dest/SPEC.md"
cd "$dest"
git config user.name "fixture"
git config user.email "fixture@example.com"
git add SPEC.md
git commit -q --amend --no-edit
echo "autopilot-sms: SPEC.md amended into base $(git rev-parse --short HEAD) ($(git rev-list --count HEAD) commit)"
