#!/usr/bin/env bash
# Scope bundle of the pre-commit review for the {{.Plugin}} plugin.
#
# Resolves the review's scope from the rung the caller names, writes the bundle
# the hunters and the comment critic read, and prints one summary line whose
# last word is the bundle path. The bundle is the only thing the review writes.
#
# Usage:  bash scripts/ldd-scope.sh [options] [<file>...]
#   Rungs — the first that applies:
#     <file>...            an explicit scope; the diff is the working tree
#                          against HEAD for those files
#     --base <ref>         the branch against its base: <ref>...HEAD
#     --all                every source file of the repository; no diff
#     (none)               the working tree against HEAD, plus untracked files
#   --root <dir>           the reviewed repository (default: cwd)
#   --out <dir>            write the bundle here (default: a new mktemp -d)
#   --max-lines <n>        a file longer than this is listed, not bundled
#                          (default 2000)
#   --glob <pattern>       source-file glob, when the language block cannot
#                          tell it from the repository ({{.Lang}} block below)
#   --test-re <ERE>        test-file pattern over relative paths, same case
#
# The bundle:
#   files.txt      the scope, one relative path per line. A file left out of
#                  scope/ keeps its line with the reason: (not bundled: deleted),
#                  (not bundled: binary), (not bundled: <n> lines) over the
#                  limit, (not bundled: generated) by the language's markers.
#                  Nothing else is filtered.
#   diff.patch     on a scoped rung, git's unified diff over the scope's source
#                  files, paths relative to --root (git diff --relative); untracked files have no diff and appear under scope/
#                  only; --all writes none
#   scope/<path>.txt  one per bundled file: a "==> <path> <==" header, then the
#                  text with its own line numbers (cat -n), so a finding read
#                  from the bundle anchors like a grep -n hit
#   dirs.txt       on --all: "<dir> TAB <files> TAB <lines>" per source
#                  directory, for the hunters' reading orders
#   comments.txt   the comment lines the critic judges, "file:line:text": on a
#                  scoped rung the diff's added lines that carry the language's
#                  comment marker plus every comment line of an untracked file,
#                  on --all every comment line of the bundled files — minus
#                  directive lines (pragmas, build tags, the
#                  linter's suppression directive, doc-test output markers)
#
# Summary line (stdout, last word the bundle path):
#   ldd-scope: <n> files bundled, <m> listed not bundled, diff <k> lines, <c> comment lines → <bundle>
# An empty scope writes no bundle and prints "ldd-scope: nothing to review";
# the caller reports that, never a clean verdict.
#
# Exit codes: 0 bundle written (or nothing to review) · 2 usage error, not a
#             git repository on a rung that needs one, or a --out that is not
#             an empty directory
#
# Uses only POSIX-portable tools plus git: grep, sed, awk, sort, wc, cat, head.

set -u

SCRIPT_NAME="ldd-scope"
ROOT="$(pwd)"
OUT=""
MAX_LINES=2000
OPT_GLOB=""
OPT_TEST_RE=""
RUNG="worktree"
BASE=""
EXPLICIT=()

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "$SCRIPT_NAME: $*" >&2; exit 2; }

while (( $# > 0 )); do
  case "$1" in
    --root)      ROOT="${2:-}"; shift 2 ;;
    --out)       OUT="${2:-}"; shift 2 ;;
    --max-lines) MAX_LINES="${2:-}"; shift 2 ;;
    --glob)      OPT_GLOB="${2:-}"; shift 2 ;;
    --test-re)   OPT_TEST_RE="${2:-}"; shift 2 ;;
    --base)      RUNG="base"; BASE="${2:-}"; shift 2 ;;
    --all)       RUNG="all"; shift ;;
    -h|--help)   usage ;;
    --)          shift; while (( $# > 0 )); do EXPLICIT+=("$1"); shift; done ;;
    --*)         die "unknown option: $1" ;;
    *)           EXPLICIT+=("$1"); shift ;;
  esac
done
[[ "$MAX_LINES" =~ ^[0-9]+$ ]] || die "--max-lines takes a number, got: $MAX_LINES"
[[ -d "$ROOT" ]] || die "not a directory: $ROOT"
if (( ${#EXPLICIT[@]} > 0 )); then
  [[ "$RUNG" == "worktree" ]] || die "an explicit file list and --$RUNG do not combine"
  RUNG="explicit"
fi
if [[ -n "$OUT" ]]; then
  OUT=$(mkdir -p "$OUT" && cd "$OUT" && pwd) || die "cannot create --out: $OUT"
  [[ -z "$(ls -A "$OUT")" ]] || die "--out is not empty: $OUT"
fi
cd "$ROOT" || exit 2

{{include "scripts/ldd-lang.sh"}}

lang_configure || exit 2

in_git() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }
need_git() { in_git || die "not a git repository: $ROOT (pass files, or --all)"; }

# ---------- the scope, per rung ----------
# SCOPE holds relative paths, sorted and unique, limited to the language's
# source files outside the excluded directories. Deleted files stay: they are
# listed with their reason.
SCOPE=()
add_scope() { # reads paths on stdin — fed by process substitution, never a pipe,
              # so the array fills in this shell
  local f
  while IFS= read -r f; do
    f="${f#./}"
    [[ -z "$f" ]] && continue
    case "$(basename "$f")" in $LANG_SRC_GLOB) ;; *) continue ;; esac
    printf '%s\n' "$f" | grep -qE -- "$LANG_EXCLUDE_RE" && continue
    SCOPE+=("$f")
  done
}
DIFF_ARGS=()
case "$RUNG" in
  explicit)
    add_scope < <(printf '%s\n' "${EXPLICIT[@]}")
    in_git && DIFF_ARGS=(--relative HEAD --)
    ;;
  base)
    need_git
    git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null || die "no such base ref: $BASE"
    add_scope < <(git diff --name-only --relative "$BASE...HEAD" -- "$LANG_SRC_GLOB")
    DIFF_ARGS=(--relative "$BASE...HEAD" --)
    ;;
  all)
    if in_git; then
      add_scope < <(git ls-files --cached --others --exclude-standard -- "$LANG_SRC_GLOB")
    else
      add_scope < <(find . -type f -name "$LANG_SRC_GLOB")
    fi
    ;;
  worktree)
    need_git
    add_scope < <(git diff --name-only --relative HEAD -- "$LANG_SRC_GLOB"; git ls-files --others --exclude-standard -- "$LANG_SRC_GLOB")
    DIFF_ARGS=(--relative HEAD --)
    ;;
esac
if (( ${#SCOPE[@]} > 0 )); then
  sorted=$(printf '%s\n' "${SCOPE[@]}" | LC_ALL=C sort -u)
  SCOPE=()
  while IFS= read -r f; do SCOPE+=("$f"); done <<< "$sorted"
fi
if (( ${#SCOPE[@]} == 0 )); then
  echo "$SCRIPT_NAME: nothing to review"
  exit 0
fi

# ---------- the bundle ----------
[[ -n "$OUT" ]] || OUT=$(mktemp -d)
mkdir -p "$OUT/scope"

# not_bundled_reason <file> — prints the reason, or nothing when it is bundled
not_bundled_reason() {
  local f="$1" n
  [[ -e "$f" ]] || { printf 'deleted'; return; }
  [[ -f "$f" ]] || { printf 'not a regular file'; return; }
  if [[ -s "$f" ]] && ! grep -Iq . -- "$f" 2>/dev/null; then printf 'binary'; return; fi
  n=$(wc -l < "$f" | tr -d ' ')
  (( n > MAX_LINES )) && { printf '%s lines' "$n"; return; }
  head -5 -- "$f" | grep -qE -- "$LANG_GENERATED_RE" && { printf 'generated'; return; }
  return 0
}

BUNDLED=()
n_listed=0
: > "$OUT/files.txt"
for f in "${SCOPE[@]}"; do
  reason=$(not_bundled_reason "$f")
  if [[ -n "$reason" ]]; then
    printf '%s (not bundled: %s)\n' "$f" "$reason" >> "$OUT/files.txt"
    n_listed=$((n_listed + 1))
    continue
  fi
  printf '%s\n' "$f" >> "$OUT/files.txt"
  BUNDLED+=("$f")
  mkdir -p "$OUT/scope/$(dirname "$f")"
  { printf '==> %s <==\n' "$f"; cat -n -- "$f"; } > "$OUT/scope/$f.txt"
done

diff_lines=0
if (( ${#DIFF_ARGS[@]} > 0 )); then
  if [[ "$RUNG" == "explicit" ]]; then
    git diff "${DIFF_ARGS[@]}" "${SCOPE[@]}" > "$OUT/diff.patch" 2>/dev/null || : > "$OUT/diff.patch"
  else
    git diff "${DIFF_ARGS[@]}" "$LANG_SRC_GLOB" > "$OUT/diff.patch" 2>/dev/null || : > "$OUT/diff.patch"
  fi
  diff_lines=$(wc -l < "$OUT/diff.patch" | tr -d ' ')
fi

if [[ "$RUNG" == "all" ]] && (( ${#BUNDLED[@]} > 0 )); then
  for f in "${BUNDLED[@]}"; do
    printf '%s\t%s\n' "$(dirname "$f")" "$(wc -l < "$f" | tr -d ' ')"
  done | awk -F'\t' '{ files[$1]++; lines[$1] += $2 } END { for (d in files) printf "%s\t%d\t%d\n", d, files[d], lines[d] }' \
       | LC_ALL=C sort > "$OUT/dirs.txt"
fi

# comments.txt — the critic's prefilter: added comment lines on a scoped rung,
# every comment line of the bundle on --all; directives never count.
# comment_lines_of <file>... — every comment line of the files, grep -nH shape
comment_lines_of() {
  (( $# > 0 )) || return 0
  LC_ALL=C grep -nHE -e "$LANG_COMMENT_RE" -- "$@" 2>/dev/null | LC_ALL=C grep -vE -- "$LANG_DIRECTIVE_RE"
}
: > "$OUT/comments.txt"
if [[ "$RUNG" == "all" ]]; then
  comment_lines_of ${BUNDLED[@]+"${BUNDLED[@]}"} > "$OUT/comments.txt"
else
  if [[ -s "$OUT/diff.patch" ]]; then
    awk '
      /^\+\+\+ / { f = $2; sub(/^b\//, "", f); next }
      /^--- / { next }
      /^@@ / { s = $3; sub(/^\+/, "", s); sub(/,.*$/, "", s); n = s - 1; next }
      /^\+/ { n++; print f ":" n ":" substr($0, 2); next }
      /^-/ { next }
      { n++ }
    ' "$OUT/diff.patch" | LC_ALL=C grep -E -- "^[^:]*:[0-9]+:.*($LANG_COMMENT_RE)" | LC_ALL=C grep -vE -- "$LANG_DIRECTIVE_RE" >> "$OUT/comments.txt"
  fi
  # an untracked file has no diff: every line of it is added, comments included
  if in_git && (( ${#BUNDLED[@]} > 0 )); then
    UNTRACKED=()
    while IFS= read -r f; do
      for b in "${BUNDLED[@]}"; do [[ "$b" == "$f" ]] && UNTRACKED+=("$f"); done
    done < <(git ls-files --others --exclude-standard -- "$LANG_SRC_GLOB")
    comment_lines_of ${UNTRACKED[@]+"${UNTRACKED[@]}"} >> "$OUT/comments.txt"
  fi
fi
comment_lines=$(wc -l < "$OUT/comments.txt" | tr -d ' ')

echo "$SCRIPT_NAME: ${#BUNDLED[@]} files bundled, $n_listed listed not bundled, diff $diff_lines lines, $comment_lines comment lines → $OUT"
exit 0
