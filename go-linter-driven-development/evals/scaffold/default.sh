#!/usr/bin/env bash
# Scaffold the go-mini fixture into <dest> as a fresh git repo with one commit.
# Every eval case starts from this: the plugin's diff-based commands (git diff,
# git log ratchets) need a base commit, and the agent under test must see a
# repository, not a loose directory.
#
# Usage: scaffold/default.sh <dest-dir>
set -euo pipefail

dest="${1:?usage: default.sh <dest-dir>}"
here=$(cd "$(dirname "$0")" && pwd)
fixture="$here/../fixtures/go-mini"

mkdir -p "$dest"
cp -R "$fixture/." "$dest/"
cd "$dest"
git init -q
git -c user.name=fixture -c user.email=fixture@example.com add -A
git -c user.name=fixture -c user.email=fixture@example.com commit -q -m "go-mini: initial import"
echo "scaffolded go-mini at $dest ($(git rev-parse --short HEAD))"
