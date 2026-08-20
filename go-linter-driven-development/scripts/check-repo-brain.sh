#!/usr/bin/env bash
# Repo-brain conformance gate for the go-linter-driven-development plugin.
#
# Runs R9's mechanical falsifying questions over the repo's doc root (an OKF
# bundle) so CI — and developers without the plugin — can hold the
# documentation network's invariants. Installed into target repos by the
# documentation skill's BOOTSTRAP pass (/wire-repo-brain).
#
# Usage:  bash scripts/check-repo-brain.sh [repo-root]     (default: cwd)
# CI:     one line — bash scripts/check-repo-brain.sh
#
# Checks (numbering follows rules/R9-repo-brain.md's falsifying questions):
#   Q1  orphans        — every non-index doc has an index line reaching it
#   Q2  edges          — code→docs paths resolve; doc-cited exported symbols
#                        grep in the repo; no file:line citations (URLs exempt)
#   Q3  root wiring    — CLAUDE.md or AGENTS.md references the index
#   Q7  bundle contract— frontmatter on every doc-root .md; `type: index` and
#                        no `timestamp:` on indexes; no `related:` key; no log.md
#
# Heuristics (documented, deliberate):
#   - docs→code checks only backticked tokens shaped like exported Go
#     identifiers (`Foo`, `Foo.Bar`) that contain a lowercase letter; other
#     backticks (paths, flags, ALL-CAPS initialisms, <placeholders>) are skipped.
#   - lines carrying the ⚠️ stale flag or a *(planned)* marker are exempt from
#     symbol resolution (R9 Q2's two exemptions); the file:line ban has no
#     exemption beyond URLs (lines containing ://).
#   - fenced code blocks are skipped for symbol resolution.
#
# Exit codes: 0 clean (or repo has no doc root yet — advisory no-op)
#             1 one or more violations (details on stderr, summary last)
#             2 usage error
#
# Uses only POSIX-portable tools: find, grep, sed, head, sort, wc. No jq/python.

set -u

REPO_ROOT="${1:-$(pwd)}"
if [[ ! -d "$REPO_ROOT" ]]; then
  echo "check-repo-brain: not a directory: $REPO_ROOT" >&2
  exit 2
fi
cd "$REPO_ROOT" || exit 2

DOCROOT=""
for d in .ai .ainav docs; do
  [[ -d "$d" ]] && DOCROOT="$d" && break
done
if [[ -z "$DOCROOT" ]]; then
  echo "check-repo-brain: no doc root (.ai/, .ainav/, docs/) — nothing to check yet; run /wire-repo-brain to bootstrap"
  exit 0
fi

violations=0
fail() {
  echo "  $1 — see $DOCROOT/conventions.md" >&2
  violations=$((violations + 1))
}

# canon <path> -> physical path with .. resolved (empty if parent dir missing)
canon() {
  local dir base
  dir=$(dirname "$1")
  base=$(basename "$1")
  (cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$base")
}

# resolve_link <containing-file> <target> -> absolute path ('' for URLs/anchors)
resolve_link() {
  local from="$1" target="$2"
  target="${target%%#*}"
  [[ -z "$target" || "$target" == *"://"* ]] && return 0
  if [[ "$target" == /* ]]; then
    printf '%s\n' "$(canon "$DOCROOT/${target#/}")"   # bundle-relative (OKF)
  else
    printf '%s\n' "$(canon "$(dirname "$from")/$target")"
  fi
}

# ---------- Q1: orphans — every non-index doc reachable from an index ----------
indexed_targets=""
while IFS= read -r idx; do
  while IFS= read -r raw; do
    t="${raw#](}"; t="${t%)}"
    [[ "$t" == *.md ]] || continue
    resolved=$(resolve_link "$idx" "$t")
    [[ -n "$resolved" ]] && indexed_targets="$indexed_targets$resolved
"
  done < <(grep -oE '\]\([^)]+\)' "$idx" 2>/dev/null)
done < <(find "$DOCROOT" -type f -name 'index.md')

while IFS= read -r doc; do
  c=$(canon "$doc")
  if ! printf '%s' "$indexed_targets" | grep -Fxq "$c"; then
    fail "[Q1] $doc — orphan: no index.md lists it"
  fi
done < <(find "$DOCROOT" -type f -name '*.md' ! -name 'index.md')

# ---------- Q2: code→docs edges and doc→doc links resolve ----------
have_go=0
if find . -name '*.go' -not -path './vendor/*' -not -path './.git/*' -print -quit 2>/dev/null | grep -q .; then
  have_go=1
fi

if (( have_go )); then
  while IFS= read -r hit; do
    file="${hit%%:*}"; rest="${hit#*:}"; line="${rest%%:*}"; target="${rest#*:}"
    [[ -f "$target" ]] || fail "[Q2] $file:$line — code edge points at missing $target"
  done < <(grep -rnoE '(docs|\.ai|\.ainav)/[A-Za-z0-9._/-]+\.md' \
             --include='*.go' --exclude-dir=vendor --exclude-dir=.git . 2>/dev/null)
fi

while IFS= read -r md; do
  while IFS= read -r raw; do
    t="${raw#](}"; t="${t%)}"
    [[ "$t" == *.md* ]] || continue
    resolved=$(resolve_link "$md" "$t")
    [[ -z "$resolved" ]] && continue
    [[ -f "$resolved" ]] || fail "[Q2] $md — link target does not exist: $t"
  done < <(grep -oE '\]\([^)]+\)' "$md" 2>/dev/null)
done < <(find "$DOCROOT" -type f -name '*.md')

# ---------- Q2: docs→code — backticked exported symbols must grep ----------
if (( have_go )); then
  while IFS= read -r md; do
    in_fence=0
    lineno=0
    while IFS= read -r line; do
      lineno=$((lineno + 1))
      case "$line" in '```'*) in_fence=$((1 - in_fence)); continue ;; esac
      (( in_fence )) && continue
      case "$line" in *'⚠️'*|*'*(planned)*'*) continue ;; esac
      while IFS= read -r tok; do
        tok="${tok#\`}"; tok="${tok%\`}"
        printf '%s' "$tok" | grep -qE '^[A-Z][A-Za-z0-9]*(\.[A-Z][A-Za-z0-9]*)?$' || continue
        printf '%s' "$tok" | grep -q '[a-z]' || continue
        if [[ "$tok" == *.* ]]; then
          method="${tok#*.}"
          grep -rqE "\) ?[A-Za-z0-9_]* ?\*?[A-Za-z0-9_]*\) ${method}\(|func .*\) ${method}\(" \
            --include='*.go' --exclude-dir=vendor --exclude-dir=.git . 2>/dev/null && continue
          grep -rqE "func ${method}\(" \
            --include='*.go' --exclude-dir=vendor --exclude-dir=.git . 2>/dev/null && continue
          fail "[Q2] $md:$lineno — backticked \`$tok\` does not resolve (method ${method} not found)"
        else
          grep -rqE "(type|func) ${tok}\b" \
            --include='*.go' --exclude-dir=vendor --exclude-dir=.git . 2>/dev/null && continue
          fail "[Q2] $md:$lineno — backticked \`$tok\` does not resolve (no type/func ${tok})"
        fi
      done < <(printf '%s\n' "$line" | grep -oE '`[^`]+`')
    done < "$md"
  done < <(find "$DOCROOT" -type f -name '*.md')
fi

# ---------- Q2: file:line citation ban (URLs exempt) ----------
while IFS= read -r hit; do
  file="${hit%%:*}"; rest="${hit#*:}"; line="${rest%%:*}"
  fail "[Q2] $file:$line — cites a file path or line number (churn-prone coordinate)"
done < <(grep -rnE '\.go(:[0-9]+)?|line [0-9]+' "$DOCROOT" --include='*.md' 2>/dev/null | grep -v '://')

# ---------- Q3: root wiring ----------
if ! grep -l 'index.md' CLAUDE.md AGENTS.md >/dev/null 2>&1; then
  fail "[Q3] repo root — neither CLAUDE.md nor AGENTS.md references $DOCROOT/index.md"
fi

# ---------- Q7: bundle contract ----------
while IFS= read -r md; do
  if [[ "$(head -1 "$md" 2>/dev/null)" != "---" ]]; then
    fail "[Q7] $md — no frontmatter block (first line must be ---)"
    continue
  fi
  fm=$(sed -n '2,/^---$/p' "$md")
  if printf '%s\n' "$fm" | grep -q '^related:'; then
    fail "[Q7] $md — 'related:' frontmatter key (links live in the body)"
  fi
  if [[ "$(basename "$md")" == "index.md" ]]; then
    printf '%s\n' "$fm" | grep -q '^type: index' \
      || fail "[Q7] $md — index frontmatter missing 'type: index'"
    if printf '%s\n' "$fm" | grep -q '^timestamp:'; then
      fail "[Q7] $md — timestamp on an index (derived files get no authored churn)"
    fi
  fi
done < <(find "$DOCROOT" -type f -name '*.md')

while IFS= read -r lg; do
  fail "[Q7] $lg — log.md is reserved for change history; docs describe current behavior"
done < <(find "$DOCROOT" -type f -name 'log.md')

# ---------- summary ----------
if (( violations > 0 )); then
  echo "check-repo-brain: $violations violation(s) in $DOCROOT/ — rules: $DOCROOT/conventions.md" >&2
  exit 1
fi
echo "check-repo-brain: clean ($DOCROOT/)"
exit 0
