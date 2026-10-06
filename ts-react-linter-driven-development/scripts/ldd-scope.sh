#!/usr/bin/env bash
# Scope bundle of the pre-commit review for the ts-react-linter-driven-development plugin.
#
# Resolves the review's scope from the rung the caller names, writes the bundle
# the hunters and the comment critic read, and prints one summary line whose
# last word is the bundle path. The bundle is the only thing the review writes.
#
# Usage:  bash scripts/ldd-scope.sh [options] [<file>...]
#   Rungs — the first that applies:
#     <file>...            an explicit scope — files, or directories expanded
#                          to the source files under them; the diff is the
#                          working tree against HEAD for those files
#     --base <ref>         the branch against its base: <ref>...HEAD
#     --all                every source file of the repository; no diff
#     (none)               the working tree against HEAD, plus untracked files
#   --root <dir>           the reviewed repository (default: cwd)
#   --out <dir>            write the bundle here (default: a new mktemp -d)
#   --max-lines <n>        a file longer than this is listed, not bundled
#                          (default 2000)
#   --glob <pattern>       source-file glob, when the language block cannot
#                          tell it from the repository (TypeScript + React block below)
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
#   comments.txt   the comment lines the critic judges, "file:line:text ⏎ code",
#                  the code being the first non-blank, non-comment line below
#                  the comment — the declaration it documents, so the critic
#                  can tell a comment's subject without opening the file: on a
#                  scoped rung the diff's added lines that carry the language's
#                  comment marker, plus every comment line of a bundled file the
#                  diff does not touch (an untracked file, or a committed file
#                  named on the command line); on --all every comment line of
#                  the bundled files — minus directive lines (pragmas, build
#                  tags, the linter's suppression directive, doc-test output
#                  markers)
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

# ===================== language block: ts-react =====================
# Everything language-specific the review scripts need. The driver calls only
# the LANG_* variables and lang_* functions defined here; a build of the script
# for another language replaces this block and nothing else.
#
# Contract:
#   LANG_SRC_GLOB       find(1) -name pattern for the language's source files
#   LANG_EXCLUDE_RE     ERE over a relative path: directories never in scope
#   LANG_SUPPRESS_RE    ERE: a lint-suppression directive on a source line
#   LANG_COMMENT_RE     ERE: a source line that carries a comment
#   LANG_DIRECTIVE_RE   ERE: a comment line that is a directive, not prose
#   LANG_GENERATED_RE   ERE: a marker in a file's head that says it is generated
#   lang_configure      reads OPT_GLOB / OPT_TEST_RE (set by --glob / --test-re)
#   lang_is_test <path> exit 0 iff the path is a test file
#
# One glob has to cover `.ts` and `.tsx` (the driver passes it to find -name, a
# case pattern and git pathspecs alike), so it is `*.ts*`; the names that glob
# also admits — declaration files, `tsconfig.tsbuildinfo`, Vitest snapshots,
# `.tsv` data — are dropped by the exclude pattern, which the driver applies to
# every candidate path after the glob.
LANG_SRC_GLOB='*.ts*'
LANG_EXCLUDE_RE='(^|/)(node_modules|dist|build|\.next|coverage|\.git|storybook-static)/|\.d\.ts$|\.tsbuildinfo$|\.snap$|\.tsv$'
LANG_SUPPRESS_RE='eslint-disable(-next-line|-line)?|@ts-(expect-error|ignore|nocheck)|prettier-ignore'
LANG_COMMENT_RE='//|/\*|^\s*\*'
LANG_DIRECTIVE_RE='eslint-(disable|enable)|@ts-(expect-error|ignore|nocheck|check)|prettier-ignore|/// <reference|@vitest-environment|istanbul ignore|c8 ignore|biome-ignore'
LANG_GENERATED_RE='Generated by|DO NOT EDIT|@generated|automatically generated'

lang_configure() {
  [[ -n "${OPT_GLOB:-}" ]] && LANG_SRC_GLOB="$OPT_GLOB"
  return 0
}

# Stories (`*.stories.tsx`) are not production code either: Storybook renders
# them, nothing ships them, so their sleeps and doubles are judged as a test's.
lang_is_test() {
  [[ -n "${OPT_TEST_RE:-}" ]] && { printf '%s\n' "$1" | grep -qE -- "$OPT_TEST_RE"; return; }
  case "$1" in
    *.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx|*.stories.tsx) return 0 ;;
    __tests__/*|*/__tests__/*|test-utils/*|*/test-utils/*|tests/*|*/tests/*|e2e/*|*/e2e/*) return 0 ;;
  esac
  return 1
}
# =================== end language block: ts-react ===================

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
    # a directory argument stands for the source files under it
    for f in "${EXPLICIT[@]}"; do
      if [[ -d "$f" ]]; then
        if in_git; then add_scope < <(git ls-files --cached --others --exclude-standard -- "$f" | grep -E -- "$(printf '%s' "$LANG_SRC_GLOB" | sed 's/[.]/\\./g; s/\*/.*/g')\$")
        else add_scope < <(find "$f" -type f -name "$LANG_SRC_GLOB"); fi
      else
        add_scope < <(printf '%s\n' "$f")
      fi
    done
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

# comments.txt — the critic's inventory: on a scoped rung the diff's added
# comment lines plus every comment line of a bundled file the diff does not
# touch (untracked, or committed and named on the command line); every comment
# line of the bundle on --all; directives never count.
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
  # a bundled file the diff does not touch has no added lines: every comment
  # line of it is the critic's (an untracked file, or a committed file named
  # on the command line on a clean tree)
  if (( ${#BUNDLED[@]} > 0 )); then
    touched=$(awk '/^\+\+\+ / { f = $2; sub(/^b\//, "", f); print f }' "$OUT/diff.patch" 2>/dev/null)
    UNTOUCHED=()
    for b in "${BUNDLED[@]}"; do
      printf '%s\n' "$touched" | grep -qxF -- "$b" || UNTOUCHED+=("$b")
    done
    comment_lines_of ${UNTOUCHED[@]+"${UNTOUCHED[@]}"} >> "$OUT/comments.txt"
  fi
fi
# Each comment line gets the first code line below it (" ⏎ <code>"): the
# declaration a doc comment documents, or the statement an in-body comment
# names. Files are read once each, in comments.txt order.
if [[ -s "$OUT/comments.txt" ]]; then
  LC_ALL=C sort -t: -k1,1 -k2,2n "$OUT/comments.txt" | awk -v cre="^[ \t]*($LANG_COMMENT_RE)" '
    {
      i = index($0, ":"); f = substr($0, 1, i - 1); rest = substr($0, i + 1)
      j = index(rest, ":"); l = substr(rest, 1, j - 1) + 0
      if (f != cur) { cur = f; n = 0; delete buf; while ((getline line < f) > 0) buf[++n] = line; close(f) }
      code = ""
      for (k = l + 1; k <= n; k++) {
        s = buf[k]
        if (s ~ /^[ \t]*$/ || s ~ cre) continue
        gsub(/\t/, " ", s); sub(/^ +/, "", s); sub(/ +$/, "", s); code = substr(s, 1, 160); break
      }
      print $0 (code == "" ? "" : " ⏎ " code)
    }' > "$OUT/comments.tmp" && mv "$OUT/comments.tmp" "$OUT/comments.txt"
fi
comment_lines=$(wc -l < "$OUT/comments.txt" | tr -d ' ')

echo "$SCRIPT_NAME: ${#BUNDLED[@]} files bundled, $n_listed listed not bundled, diff $diff_lines lines, $comment_lines comment lines → $OUT"
exit 0
