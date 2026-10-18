#!/usr/bin/env bash
# Scope bundle of the pre-commit review for the linter-driven-development plugin.
#
# Resolves the review's scope from the rung the caller names, splits it by the
# language of each file, writes one bundle per language group — the bundle the
# hunters and the comment critic read — and prints one summary line per group
# plus a last line whose last word is the path to hand to ldd-detect.sh. The
# bundles are the only thing the review writes.
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
#   --glob <pattern>       review only the files matching this glob, as one
#                          group of a language the table does not know
#   --test-re <ERE>        test-file pattern over relative paths, every group
#   --lang <id>            review only this language group, here, with no
#                          routing — the flag a plugin passes when it routes a
#                          group to this one
#
# Languages: a file's language is told by its extension (the language table
# below); a file with no source extension is not in scope. Every language group
# goes to the plugin that reviews it: a language this plugin's block serves is
# bundled here; a language another installed plugin is written for goes to that
# plugin's ldd-scope.sh, which writes the group's bundle; a language with no
# installed plugin of its own is bundled here when this block has a row for it,
# else by the linter-driven-development plugin when it is installed, else the
# group is excluded and every one of its files is named on stderr with the
# reason. The installed plugins are read from ~/.claude/plugins/installed_plugins.json
# (LDD_INSTALLED_PLUGINS names another file).
#
# One group reviewed here writes the bundle flat under --out. Several groups,
# or one group another plugin reviews, write groups.txt under --out and one
# bundle per group in --out/<id>/:
#   groups.txt     "<id> TAB <plugin> TAB <plugin dir> TAB <bundle dir> TAB <note>"
#                  per group, ids sorted; an excluded group has "-" in the
#                  plugin, dir and bundle columns and its reason in the note
#
# The bundle:
#   language.txt   the group's language id; "custom TAB <glob>" under --glob
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
# Summary lines (stdout, last word of the last line the path for ldd-detect.sh):
#   ldd-scope: <n> files bundled, <m> listed not bundled, diff <k> lines, <c> comment lines → <bundle>
#   and with several groups, one line per group first:
#   ldd-scope[<id> via <plugin>]: <n> files bundled, … → <bundle>
#   ldd-scope[<id>]: <n> files excluded: no language block matched (.<ext>)
#   ldd-scope: <g> language groups (<ids>), <x> excluded → <dir>
# An empty scope writes no bundle and prints "ldd-scope: nothing to review";
# the caller reports that, never a clean verdict.
#
# Exit codes: 0 bundle written (or nothing to review) · 1 every group was
#             excluded: the scope holds source files no installed plugin
#             reviews, named on stderr · 2 usage error, not a git repository on
#             a rung that needs one, or a --out that is not an empty directory
#
# Uses only POSIX-portable tools plus git: grep, sed, awk, sort, wc, cat, head.

set -u

SCRIPT_NAME="ldd-scope"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PLUGIN_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
PLUGIN_NAME="linter-driven-development"
ROOT="$(pwd)"
OUT=""
MAX_LINES=2000
OPT_GLOB=""
OPT_TEST_RE=""
OPT_LANG=""
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
    --lang)      OPT_LANG="${2:-}"; shift 2 ;;
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
[[ -n "$OPT_GLOB" && -n "$OPT_LANG" ]] && die "--glob and --lang do not combine"
if [[ -n "$OUT" ]]; then
  OUT=$(mkdir -p "$OUT" && cd "$OUT" && pwd) || die "cannot create --out: $OUT"
  [[ -z "$(ls -A "$OUT")" ]] || die "--out is not empty: $OUT"
fi
cd "$ROOT" || exit 2
ROOT=$(pwd)

# ==================== language table ====================
# How a file's language is told, and which plugin owns a language. The same
# table is rendered into every plugin, so two plugins that split one scope
# agree on every file. The language block below says which of these ids this
# plugin reviews itself; the rest are routed to the plugin that owns them.
# residue-exempt: the table names every language's extension and plugin on
# purpose, the same in every rendering.
#
#   lang_of_path <path>       the language id of a source file, by extension:
#                             "custom" for a file matching --glob (then nothing
#                             else is a source file), "" for a file that is not
#                             source (a manifest, a doc, a build file)
#   dedicated_plugin_for <id> the plugin written for that language, or ""
#   GENERIC_PLUGIN            the plugin that reviews any language
#   installed_plugin_dir <n>  where plugin <n> is installed, from the
#                             installed-plugins file, or "" when it is not;
#                             LDD_INSTALLED_PLUGINS names another file
GENERIC_PLUGIN='linter-driven-development'

# A .h header is C++ when the repository has C++ sources, C otherwise.
HEADER_LANG=""
header_lang() {
  [[ -n "$HEADER_LANG" ]] && { printf '%s' "$HEADER_LANG"; return; }
  if { git ls-files -- '*.cpp' '*.cc' '*.cxx' '*.hpp' 2>/dev/null || find . -type f \( -name '*.cpp' -o -name '*.cc' -o -name '*.cxx' -o -name '*.hpp' \) -not -path './.git/*' 2>/dev/null; } | head -1 | grep -q .; then
    HEADER_LANG=cpp
  else
    HEADER_LANG=c
  fi
  printf '%s' "$HEADER_LANG"
}

lang_of_path() {
  local b="${1##*/}"
  if [[ -n "${OPT_GLOB:-}" ]]; then
    case "$b" in $OPT_GLOB) printf 'custom' ;; esac
    return 0
  fi
  case "$b" in
    *.go)                                   printf 'go' ;;
    *.py)                                   printf 'python' ;;
    *.d|*.di)                               printf 'd' ;;
    *.rs)                                   printf 'rust' ;;
    *.c)                                    printf 'c' ;;
    *.h)                                    header_lang ;;
    *.cpp|*.cc|*.cxx|*.hpp|*.hh|*.hxx)      printf 'cpp' ;;
    *.java)                                 printf 'java' ;;
    *.kt|*.kts)                             printf 'kotlin' ;;
    *.rb)                                   printf 'ruby' ;;
    *.sh|*.bash)                            printf 'shell' ;;
    *.ts|*.tsx)                             printf 'typescript' ;;
    *.js|*.jsx|*.mjs|*.cjs)                 printf 'javascript' ;;
    *.cs)                                   printf 'csharp' ;;
  esac
  return 0
}

dedicated_plugin_for() {
  case "$1" in
    go|python)              printf '%s-linter-driven-development' "$1" ;;
    typescript|javascript)  printf 'ts-react-linter-driven-development' ;;
  esac
  return 0
}

installed_plugin_dir() {
  local f="${LDD_INSTALLED_PLUGINS:-$HOME/.claude/plugins/installed_plugins.json}"
  [[ -f "$f" ]] || return 0
  awk -v key="\"$1@" '
    index($0, key) { found = 1; next }
    found && /"installPath"/ { sub(/^[^:]*:[ \t]*"/, ""); sub(/".*$/, ""); print; exit }
  ' "$f"
}
# ================== end language table ==================

# ==================== language block: any language ====================
# Everything language-specific the review scripts need. The driver calls only
# the LANG_* variables and lang_* functions defined here. This is the generic
# plugin's block: one row per language the language table above names, so a
# group of any of them is reviewed here when no plugin written for that
# language is installed. Which file is which language is the table, shared by
# every plugin; this block only says how each language writes a comment, a
# suppression directive and a test file.
#
# Contract:
#   LANG_NATIVE         the language ids this plugin reviews itself; a group of
#                       any other id is routed to the plugin that owns it
#   lang_configure <id> sets the variables below for that id; "custom" is the
#                       --glob override: a language the table does not know,
#                       reviewed with the broad row at the end;
#                       exit 2 for an id this block has no row for
#   LANG_EXCLUDE_RE     ERE over a relative path: directories never in scope
#   LANG_SUPPRESS_RE    ERE: a lint-suppression directive on a source line
#   LANG_COMMENT_RE     ERE: a source line that carries a comment (bracket
#                       expressions, no backslashes: the driver hands it to
#                       awk -v, which eats `\*` under gawk)
#   LANG_DIRECTIVE_RE   ERE: a comment line that is a directive, not prose
#   LANG_GENERATED_RE   ERE: a marker in a file's head that says it is generated
#   lang_is_test <path> exit 0 iff the path is a test file (--test-re overrides)
LANG_NATIVE="go python d rust c cpp java kotlin ruby shell typescript javascript csharp custom"
LANG_ID=""

lang_configure() {
  LANG_ID="$1"
  LANG_GENERATED_RE='Code generated .* DO NOT EDIT|DO NOT EDIT|@generated|automatically generated|Generated by'
  case "$1" in
    go)
      LANG_EXCLUDE_RE='(^|/)(vendor|\.git|testdata)/'
      LANG_SUPPRESS_RE='//nolint'
      LANG_COMMENT_RE='//'
      LANG_DIRECTIVE_RE='//(go:|nolint| Output:|line |export |extern )'
      ;;
    python)
      LANG_EXCLUDE_RE='(^|/)(\.venv|venv|\.git|node_modules|__pycache__|\.tox|build|dist)/'
      LANG_SUPPRESS_RE='#\s*(noqa|type:\s*ignore|ty:\s*ignore)'
      LANG_COMMENT_RE='(#|""")'
      LANG_DIRECTIVE_RE='#\s*(noqa|type:|ty:|pragma|fmt:|pylint:|ruff:|isort:|!)|>>>'
      ;;
    d)
      # D comments: // line, /* block */ and /+ nested +/. D-Scanner's
      # suppression is a comment: // @suppress(dscanner.<check>). A file's
      # inline `unittest` blocks test the production code beside them and keep
      # the file a production file; a test file is one under a test directory
      # or named *_test.d.
      LANG_EXCLUDE_RE='(^|/)(\.git|\.dub|vendor)/'
      LANG_SUPPRESS_RE='@suppress\('
      LANG_COMMENT_RE='(//|/[*]|/[+])'
      LANG_DIRECTIVE_RE='@suppress\(|dfmt (on|off)|#!'
      ;;
    rust)
      LANG_EXCLUDE_RE='(^|/)(\.git|target|vendor)/'
      LANG_SUPPRESS_RE='#!?\[allow\('
      LANG_COMMENT_RE='(//|/[*])'
      LANG_DIRECTIVE_RE='rustfmt::skip|clippy::'
      ;;
    c|cpp)
      LANG_EXCLUDE_RE='(^|/)(\.git|third_party|vendor)/'
      LANG_SUPPRESS_RE='NOLINT|cppcheck-suppress|#pragma (warning\s*\(\s*disable|GCC diagnostic ignored|clang diagnostic ignored)'
      LANG_COMMENT_RE='(//|/[*])'
      LANG_DIRECTIVE_RE='NOLINT|cppcheck-suppress|clang-format (on|off)|IWYU'
      ;;
    java|kotlin)
      LANG_EXCLUDE_RE='(^|/)(\.git|target|build|\.gradle)/'
      LANG_SUPPRESS_RE='@Suppress(Warnings)?\(|NOSONAR|noinspection|CHECKSTYLE:OFF|ktlint-disable|detekt:'
      LANG_COMMENT_RE='(//|/[*])'
      LANG_DIRECTIVE_RE='noinspection|CHECKSTYLE|NOSONAR|@formatter:|ktlint-|detekt:'
      ;;
    ruby)
      LANG_EXCLUDE_RE='(^|/)(\.git|vendor/bundle|tmp)/'
      LANG_SUPPRESS_RE='rubocop:disable|steep:ignore'
      LANG_COMMENT_RE='(#|=begin)'
      LANG_DIRECTIVE_RE='rubocop:|frozen_string_literal|encoding:|#!'
      ;;
    shell)
      LANG_EXCLUDE_RE='(^|/)(\.git)/'
      LANG_SUPPRESS_RE='shellcheck disable'
      LANG_COMMENT_RE='#'
      LANG_DIRECTIVE_RE='shellcheck|#!'
      ;;
    typescript|javascript)
      LANG_EXCLUDE_RE='(^|/)(\.git|node_modules|dist)/'
      LANG_SUPPRESS_RE='eslint-disable|@ts-(ignore|expect-error|nocheck)|biome-ignore'
      LANG_COMMENT_RE='(//|/[*])'
      LANG_DIRECTIVE_RE='eslint-|@ts-|prettier-ignore|biome-ignore|/// *<reference|#!'
      ;;
    csharp)
      LANG_EXCLUDE_RE='(^|/)(\.git|bin|obj)/'
      LANG_SUPPRESS_RE='#pragma warning disable|\[SuppressMessage'
      LANG_COMMENT_RE='(//|/[*])'
      LANG_DIRECTIVE_RE='ReSharper|#pragma'
      ;;
    custom)
      # A language the table does not know: every common comment marker and
      # suppression spelling, so --glob reviews it without a row of its own.
      LANG_EXCLUDE_RE='(^|/)(vendor|\.git|node_modules|\.venv|target|build|dist)/'
      LANG_SUPPRESS_RE='nolint|noqa|eslint-disable|#\[allow\(|@SuppressWarnings|type:\s*ignore|NOSONAR|rubocop:disable|shellcheck disable'
      LANG_COMMENT_RE='(//|#|/[*]|--|""")'
      LANG_DIRECTIVE_RE='//go:|nolint|#\s*(noqa|type:|pragma|!)|eslint-|@ts-|pragma'
      ;;
    *) return 2 ;;
  esac
  return 0
}

lang_is_test() {
  [[ -n "${OPT_TEST_RE:-}" ]] && { printf '%s\n' "$1" | grep -qE -- "$OPT_TEST_RE"; return; }
  case "$LANG_ID" in
    go) [[ "$1" == *_test.go ]] ;;
    python)
      case "$1" in
        *_test.py|test_*.py|*/test_*.py|conftest.py|*/conftest.py|tests/*|*/tests/*) return 0 ;;
      esac
      return 1 ;;
    d)
      case "$1" in
        *_test.d|test/*|*/test/*|tests/*|*/tests/*|testing/*|*/testing/*) return 0 ;;
      esac
      return 1 ;;
    rust)
      case "$1" in
        *_test.rs|tests/*|*/tests/*|benches/*|*/benches/*) return 0 ;;
      esac
      return 1 ;;
    java|kotlin)
      case "$1" in
        *Test.java|*Tests.java|*IT.java|*Test.kt|*Tests.kt|src/test/*|*/src/test/*|src/*Test/*|*/src/*Test/*) return 0 ;;
      esac
      return 1 ;;
    ruby)
      case "$1" in
        *_spec.rb|*_test.rb|spec/*|*/spec/*|test/*|*/test/*) return 0 ;;
      esac
      return 1 ;;
    csharp)
      case "$1" in
        *Test.cs|*Tests.cs|*.Tests/*|*/*.Tests/*|test/*|*/test/*|tests/*|*/tests/*) return 0 ;;
      esac
      return 1 ;;
    *)
      case "$1" in
        *_test.*|*.test.*|*.spec.*|*Test.*|test_*|*/test_*|test/*|*/test/*|tests/*|*/tests/*|spec/*|*/spec/*|__tests__/*|*/__tests__/*) return 0 ;;
      esac
      return 1 ;;
  esac
}
# ================== end language block: any language ==================

is_native() { case " $LANG_NATIVE " in *" $1 "*) return 0 ;; esac; return 1; }
if [[ -n "$OPT_LANG" ]]; then
  is_native "$OPT_LANG" || die "this plugin has no language block for $OPT_LANG"
fi

in_git() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }
need_git() { in_git || die "not a git repository: $ROOT (pass files, or --all)"; }

# ---------- the candidates, per rung ----------
# Every file the rung names, before any language is told; deleted files stay,
# they are listed with their reason.
CANDIDATES=$(mktemp)
trap 'rm -f "$CANDIDATES" "${CLASSIFIED:-}"' EXIT
DIFF_ARGS=()
case "$RUNG" in
  explicit)
    # a directory argument stands for the source files under it
    for f in "${EXPLICIT[@]}"; do
      if [[ -d "$f" ]]; then
        if in_git; then git ls-files --cached --others --exclude-standard -- "$f"
        else find "$f" -type f; fi
      else
        printf '%s\n' "$f"
      fi
    done > "$CANDIDATES"
    in_git && DIFF_ARGS=(--relative HEAD --)
    ;;
  base)
    need_git
    git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null || die "no such base ref: $BASE"
    git diff --name-only --relative "$BASE...HEAD" > "$CANDIDATES"
    DIFF_ARGS=(--relative "$BASE...HEAD" --)
    ;;
  all)
    if in_git; then git ls-files --cached --others --exclude-standard > "$CANDIDATES"
    else find . -type f -not -path './.git/*' > "$CANDIDATES"; fi
    ;;
  worktree)
    need_git
    { git diff --name-only --relative HEAD; git ls-files --others --exclude-standard; } > "$CANDIDATES"
    DIFF_ARGS=(--relative HEAD --)
    ;;
esac

# ---------- the groups: one per language in the scope ----------
# CLASSIFIED holds "<id> TAB <path>" per source file, sorted and unique.
CLASSIFIED=$(mktemp)
n_candidates=0
unknown_exts=""
while IFS= read -r f; do
  f="${f#./}"
  [[ -z "$f" ]] && continue
  n_candidates=$((n_candidates + 1))
  id=$(lang_of_path "$f")
  if [[ -z "$id" ]]; then
    case "$f" in *.*) ext=".${f##*.}"; case " $unknown_exts " in *" $ext "*) ;; *) unknown_exts="$unknown_exts $ext" ;; esac ;; esac
    continue
  fi
  [[ -n "$OPT_LANG" && "$id" != "$OPT_LANG" ]] && continue
  printf '%s\t%s\n' "$id" "$f" >> "$CLASSIFIED"
done < "$CANDIDATES"
LC_ALL=C sort -u -o "$CLASSIFIED" "$CLASSIFIED"

GROUP_IDS=$(cut -f1 "$CLASSIFIED" | LC_ALL=C sort -u)
if [[ -z "$GROUP_IDS" ]]; then
  echo "$SCRIPT_NAME: nothing to review"
  if [[ -n "$unknown_exts" && -z "$OPT_LANG" ]]; then
    echo "$SCRIPT_NAME: $n_candidates file(s) in the rung, none with a source extension the language table knows (${unknown_exts# }); pass --glob '<pattern>' to review one of them as a language of its own" >&2
  fi
  exit 0
fi
n_groups=$(printf '%s\n' "$GROUP_IDS" | grep -c .)

# ---------- one bundle ----------
# write_bundle <out> <file>... — the bundle of one language group, with the
# language block configured for it. Sets BUNDLED_N, LISTED_N, DIFF_LINES and
# COMMENT_N for the caller's summary line.
write_bundle() {
  local OUT="$1"; shift   # the bundle directory; the nested helpers read it
  local SCOPE=("$@")
  mkdir -p "$OUT/scope"
  if [[ "$GROUP_ID" == "custom" ]]; then printf 'custom\t%s\n' "$OPT_GLOB" > "$OUT/language.txt"
  else printf '%s\n' "$GROUP_ID" > "$OUT/language.txt"; fi

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

  local BUNDLED=() f reason
  LISTED_N=0
  : > "$OUT/files.txt"
  for f in "${SCOPE[@]}"; do
    reason=$(not_bundled_reason "$f")
    if [[ -n "$reason" ]]; then
      printf '%s (not bundled: %s)\n' "$f" "$reason" >> "$OUT/files.txt"
      LISTED_N=$((LISTED_N + 1))
      continue
    fi
    printf '%s\n' "$f" >> "$OUT/files.txt"
    BUNDLED+=("$f")
    mkdir -p "$OUT/scope/$(dirname "$f")"
    { printf '==> %s <==\n' "$f"; cat -n -- "$f"; } > "$OUT/scope/$f.txt"
  done
  BUNDLED_N=${#BUNDLED[@]}

  DIFF_LINES=0
  if (( ${#DIFF_ARGS[@]} > 0 )); then
    git diff "${DIFF_ARGS[@]}" "${SCOPE[@]}" > "$OUT/diff.patch" 2>/dev/null || : > "$OUT/diff.patch"
    DIFF_LINES=$(wc -l < "$OUT/diff.patch" | tr -d ' ')
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
      local touched b UNTOUCHED=()
      touched=$(awk '/^\+\+\+ / { f = $2; sub(/^b\//, "", f); print f }' "$OUT/diff.patch" 2>/dev/null)
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
  COMMENT_N=$(wc -l < "$OUT/comments.txt" | tr -d ' ')
}

summary_body() { printf '%s files bundled, %s listed not bundled, diff %s lines, %s comment lines → %s' "$BUNDLED_N" "$LISTED_N" "$DIFF_LINES" "$COMMENT_N" "$1"; }

# group_files <id> — the group's paths, one per line, the block's exclusions applied
group_files() {
  awk -F'\t' -v id="$1" '$1 == id { print $2 }' "$CLASSIFIED" | LC_ALL=C grep -vE -- "$LANG_EXCLUDE_RE"
  return 0
}

# bundle_here <id> <out> — the group reviewed by this plugin; exit 1 when the
# block's exclusions leave nothing
bundle_here() {
  GROUP_ID="$1"
  lang_configure "$1" || return 2
  local files=()
  while IFS= read -r f; do [[ -n "$f" ]] && files+=("$f"); done < <(group_files "$1")
  (( ${#files[@]} > 0 )) || return 1
  write_bundle "$2" "${files[@]}"
}

# ---------- one group reviewed here: the flat bundle ----------
# reviewed_here <id> — this plugin reviews the group without asking another:
# its block has the row, and no plugin written for the language is installed
# (or this plugin was handed the group by one).
reviewed_here() {
  is_native "$1" || return 1
  [[ -n "$OPT_LANG" ]] && return 0
  local d; d=$(dedicated_plugin_for "$1")
  [[ -z "$d" || "$d" == "$PLUGIN_NAME" ]] && return 0
  [[ -z "$(installed_plugin_dir "$d")" ]]
}
only_id=$(printf '%s\n' "$GROUP_IDS" | head -1)
if (( n_groups == 1 )) && reviewed_here "$only_id"; then
  [[ -n "$OUT" ]] || OUT=$(mktemp -d)
  if ! bundle_here "$only_id" "$OUT"; then
    echo "$SCRIPT_NAME: nothing to review"
    exit 0
  fi
  echo "$SCRIPT_NAME: $(summary_body "$OUT")"
  exit 0
fi

# ---------- several groups, or a group another plugin reviews ----------
[[ -n "$OUT" ]] || OUT=$(mktemp -d)
rung_args=()
case "$RUNG" in
  base)     rung_args=(--base "$BASE") ;;
  all)      rung_args=(--all) ;;
  explicit) rung_args=(-- "${EXPLICIT[@]}") ;;
esac
pass_args=(--root "$ROOT" --max-lines "$MAX_LINES")
[[ -n "$OPT_TEST_RE" ]] && pass_args+=(--test-re "$OPT_TEST_RE")

# route_to <plugin dir> <id> <out> — the group's bundle written by that
# plugin's ldd-scope.sh. Prints its summary body; exit 1 when it found nothing
# to review, 2 when it could not run.
route_to() {
  local dir="$1" id="$2" out="$3" line
  [[ -f "$dir/scripts/ldd-scope.sh" ]] || return 2
  line=$(bash "$dir/scripts/ldd-scope.sh" "${pass_args[@]}" --out "$out" --lang "$id" ${rung_args[@]+"${rung_args[@]}"} 2>/dev/null) || return 2
  case "$line" in
    *'nothing to review') return 1 ;;
    "$SCRIPT_NAME: "*) printf '%s' "${line#"$SCRIPT_NAME: "}"; return 0 ;;
  esac
  return 2
}

n_excluded=0
n_bundled_groups=0
: > "$OUT/groups.txt"
for id in $GROUP_IDS; do
  dedicated=$(dedicated_plugin_for "$id")
  plugin="" plugin_dir="" bundle="" note="" body=""
  # 1. a plugin written for the language, installed and able to take the group
  if [[ -n "$dedicated" && "$dedicated" != "$PLUGIN_NAME" ]]; then
    dir=$(installed_plugin_dir "$dedicated")
    if [[ -n "$dir" ]]; then
      if body=$(route_to "$dir" "$id" "$OUT/$id"); then
        plugin="$dedicated" plugin_dir="$dir" bundle="$OUT/$id"
      else
        case $? in
          1) note="$dedicated found nothing to review in this group" ;;
          2) [[ -f "$dir/scripts/ldd-scope.sh" ]] && note="$dedicated at $dir could not take the group" || note="$dedicated has no review scripts" ;;
        esac
        rm -rf "$OUT/$id"
      fi
    else
      note="$dedicated is not installed"
    fi
  fi
  # 2. this plugin's own block
  if [[ -z "$plugin" ]] && is_native "$id"; then
    if bundle_here "$id" "$OUT/$id"; then
      plugin="$PLUGIN_NAME" plugin_dir="$PLUGIN_DIR" bundle="$OUT/$id"
      body=$(summary_body "$bundle")
      [[ -n "$note" ]] && note="$note; reviewed here"
    else
      rm -rf "$OUT/$id"
      note="${note:+$note; }nothing to review after this block's exclusions"
      n_excluded=$((n_excluded + 1))
      printf '%s\t-\t-\t-\t%s\n' "$id" "$note" >> "$OUT/groups.txt"
      echo "$SCRIPT_NAME[$id]: $note"
      continue
    fi
  fi
  # 3. the plugin that reviews any language
  if [[ -z "$plugin" && "$PLUGIN_NAME" != "$GENERIC_PLUGIN" ]]; then
    dir=$(installed_plugin_dir "$GENERIC_PLUGIN")
    if [[ -z "$dir" ]]; then
      note="${note:+$note; }$GENERIC_PLUGIN is not installed"
    elif body=$(route_to "$dir" "$id" "$OUT/$id"); then
      plugin="$GENERIC_PLUGIN" plugin_dir="$dir" bundle="$OUT/$id"
    else
      case $? in
        1) note="${note:+$note; }$GENERIC_PLUGIN found nothing to review in this group" ;;
        *) note="${note:+$note; }$GENERIC_PLUGIN at $dir could not take the group" ;;
      esac
      rm -rf "$OUT/$id"
    fi
  fi
  # 4. nobody: the group is excluded, every file named
  if [[ -z "$plugin" ]]; then
    n=0
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      n=$((n + 1))
      echo "$f: no language block matched (.${f##*.})" >&2
    done < <(awk -F'\t' -v id="$id" '$1 == id { print $2 }' "$CLASSIFIED")
    ext=$(awk -F'\t' -v id="$id" '$1 == id { print $2; exit }' "$CLASSIFIED"); ext=".${ext##*.}"
    note="no language block matched ($ext)${note:+; $note}"
    n_excluded=$((n_excluded + 1))
    printf '%s\t-\t-\t-\t%s\n' "$id" "$note" >> "$OUT/groups.txt"
    echo "$SCRIPT_NAME[$id]: $n files excluded: $note"
    continue
  fi
  n_bundled_groups=$((n_bundled_groups + 1))
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$plugin" "$plugin_dir" "$bundle" "$note" >> "$OUT/groups.txt"
  label="$id"
  [[ "$plugin" != "$PLUGIN_NAME" ]] && label="$id via $plugin"
  [[ -n "$note" ]] && label="$label ($note)"
  echo "$SCRIPT_NAME[$label]: $body"
done

ids=$(printf '%s\n' "$GROUP_IDS" | tr '\n' ' '); ids="${ids% }"
echo "$SCRIPT_NAME: $n_groups language groups (${ids// /, }), $n_excluded excluded → $OUT"
(( n_bundled_groups > 0 )) || exit 1
exit 0
