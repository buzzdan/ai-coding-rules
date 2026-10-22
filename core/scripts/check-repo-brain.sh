#!/usr/bin/env bash
# Repo-brain conformance gate for the {{.Plugin}} plugin.
#
# Runs R9's mechanical falsifying questions over every doc root so CI — and
# developers without the plugin — can hold the documentation network's
# invariants. What it enforces is the R9 profile: a strict superset of OKF
# v0.2 (rules/R9-repo-brain.md is normative; <docroot>/conventions.md is the
# in-repo copy). Installed into target repos by the documentation skill's
# BOOTSTRAP pass (/wire-repo-brain).
#
# Usage:  bash scripts/check-repo-brain.sh [--fix] [--scope <list> [--words <list>]] [repo-root]
#         (repo-root default: cwd)
# CI:     one line — bash scripts/check-repo-brain.sh
# --fix:  rewrite drifted index lines from each target doc's `description`
#         (the one mechanical repair; everything else stays report-only)
# --scope <list>  a review's scope: one path per line, relative to repo-root
#         (code files and docs, deleted ones included). The gate then checks
#         only the docs in scope. A listed doc gets every check. A doc whose
#         text names a listed file's basename, or that cites a token with a
#         dot-separated part in --words, reports only its links into a listed
#         file, those tokens, and (an index) its lines to the listed docs.
#         Code edges are checked for the listed code files only, Q3 is skipped
#         (root wiring is the repository's state, not a diff's), and with no
#         doc in scope the doc checks are skipped. One stdout line says which:
#         "check-repo-brain: scope — <n> doc(s) to check" or
#         "check-repo-brain: scope — no doc in scope; doc checks skipped".
# --words <list>  identifiers the scoped change removes, one per line; a doc
#         that cites one of them in backticks is in scope
#
# Doc roots are discovered at the repo root AND at every sub-project (a
# directory holding the language's project marker — see the adapter below),
# using R9's order: .ai/ -> .ainav/ -> docs/.
#
# Language scope: the driver (everything outside the adapter block) is
# language-agnostic — Q1, Q3, Q7, doc links, the --fix rewriter. Everything
# that touches code — sub-project discovery, the declaration set, the
# code-edge grep, the file:line ban, the symbol token shapes — comes from the
# adapter block. This build carries the {{.Lang}} adapter; with no code files, the
# code<->docs checks are skipped and the rest still runs.
#
# Checks (numbering follows rules/R9-repo-brain.md's falsifying questions):
#   Q1  orphans        — every doc is reachable from its bundle's root index,
#                        transitively through sub-indexes
#   Q2  edges          — code→docs paths resolve; doc links resolve; doc-cited
#                        exported symbols grep in the repo; no file:line
#                        citations (URL spans stripped before the test)
#   Q3  root wiring    — CLAUDE.md or AGENTS.md in the root's owning project
#                        carries the exact <docroot>/index.md path (a monorepo
#                        sub-root may instead be linked from the repo-root
#                        index); AGENTS.md missing the reference is an advisory
#   Q7  bundle contract— content docs carry terminated frontmatter with
#                        type (feature|architecture|guide) and a non-empty
#                        description; indexes carry NO frontmatter except the
#                        root index's lone okf_version (required there, exactly
#                        one, valued "0.2"); no `related:` key; no log.md;
#                        every index line's text matches the target's
#                        `description` when it has one (⚠️ lines exempt; --fix
#                        rewrites drifted lines); a target stale by lifecycle
#                        (status: deprecated, or stale_after in the past) whose
#                        index line lacks ⚠️ is an advisory
#
# Heuristics (documented, deliberate):
#   - links are inline-markdown only (`[name](path.md)`, optional "title"
#     stripped); reference-style links are not checked.
#   - docs→code checks backticked tokens shaped like the language's exported
#     identifiers (adapter: LANG_SYMBOL_RE, LANG_QUALIFIED_RE) that contain a
#     lowercase letter, or an uppercase letter and an underscore (an UPPER_SNAKE
#     constant); other backticks (paths, flags, ALL-CAPS initialisms such as
#     `API`, <placeholders>) are skipped.
#   - resolution is against a declaration set built ONCE per run from the
#     language's code files (adapter: lang_declarations), which carries
#     ownership pairs: a qualified `pkg.Sym` or `Type.Method` resolves only
#     against its declaring package or receiver — never against a same-named
#     member elsewhere. A token missing from the set still resolves when it
#     appears as a whole word in any non-markdown repo file (config keys,
#     alert names, test helpers): in a git work tree the tracked and
#     untracked-but-not-ignored files outside the language's dependency and
#     build-output directories (adapter: LANG_PRUNE_DIRS); elsewhere every file
#     outside those directories and the common ones (bazel-*, vendor, …).
#     A `pkg.Sym` whose package is not declared in this repo is external
#     (stdlib, dependencies) and exempt.
#   - lines carrying the ⚠️ stale flag or a *(planned)* marker are exempt from
#     symbol resolution and the description copy check (R9 Q2/Q7 exemptions);
#     the file:line ban has no exemption beyond URL spans, fenced code blocks,
#     and glob patterns (a span containing `*` is a pattern, not a citation).
#   - fenced code blocks (``` or ~~~, indented up to 3 spaces; toggle, not
#     length-matched) are skipped for symbol resolution and the file:line ban.
#
# Exit codes: 0 clean (or repo has no doc root yet — advisory no-op)
#             1 one or more violations (details on stderr, summary last)
#             2 usage error, or an internal scanner failure (a failed scan is
#               inconclusive, never silently clean)
#
# Uses only POSIX-portable tools: find, grep, sed, awk, head, sort, wc, tr, xargs,
# plus git when the repository is a git work tree. No jq/python.
# awk programs avoid interval expressions ({m,n}) — mawk, Debian's default, rejects them.

set -u

FIX=0
SCOPE_LIST=""
WORDS_LIST=""
abs_list() { # <path> -> absolute path of an existing file, or exit 2
  [[ -f "$1" ]] || { echo "check-repo-brain: no such list: $1" >&2; exit 2; }
  printf '%s/%s\n' "$(cd "$(dirname "$1")" && pwd)" "$(basename "$1")"
}
while (( $# > 0 )); do
  case "$1" in
    --fix)   FIX=1; shift ;;
    --scope) SCOPE_LIST=$(abs_list "${2:-}") || exit 2; shift 2 ;;
    --words) WORDS_LIST=$(abs_list "${2:-}") || exit 2; shift 2 ;;
    --*)     echo "check-repo-brain: unknown option: $1" >&2; exit 2 ;;
    *)       break ;;
  esac
done
[[ -n "$WORDS_LIST" && -z "$SCOPE_LIST" ]] && { echo "check-repo-brain: --words needs --scope" >&2; exit 2; }
REPO_ROOT="${1:-$(pwd)}"
if [[ ! -d "$REPO_ROOT" ]]; then
  echo "check-repo-brain: not a directory: $REPO_ROOT" >&2
  exit 2
fi
cd "$REPO_ROOT" || exit 2
SCOPED=0
[[ -n "$SCOPE_LIST" ]] && SCOPED=1

{{include "scripts/repo-brain-adapter.sh"}}

# ---------- doc-root discovery: repo root + every sub-project ----------
discover_docroot() { # <project-dir> -> docroot path or ''
  local base="$1" d p
  for d in .ai .ainav docs; do
    if [[ "$base" == "." ]]; then p="$d"; else p="$base/$d"; fi
    [[ -d "$p" ]] && { printf '%s\n' "$p"; return; }
  done
}

PROJS=()
ROOTS=()
seen_roots=" "
add_root() { # <project-dir>
  local r
  r=$(discover_docroot "$1")
  [[ -z "$r" ]] && return
  case "$seen_roots" in *" $r "*) return ;; esac
  seen_roots="$seen_roots$r "
  PROJS+=("$1")
  ROOTS+=("$r")
}
add_root "."
while IFS= read -r p; do
  add_root "$p"
done < <(lang_project_dirs)

if (( ${#ROOTS[@]} == 0 )); then
  echo "check-repo-brain: no doc root (.ai/, .ainav/, docs/) at the repo root or any $LANG_PROJECT_MARKER sub-project — nothing to check yet; run /wire-repo-brain to bootstrap"
  exit 0
fi
ROOT_BUNDLE=""
for i in "${!PROJS[@]}"; do
  [[ "${PROJS[$i]}" == "." ]] && ROOT_BUNDLE="${ROOTS[$i]}"
done

violations=0
CUR_DOCROOT="${ROOTS[0]}"
fail() {
  echo "  $1 — see $CUR_DOCROOT/conventions.md" >&2
  violations=$((violations + 1))
}
note() { echo "  advisory: $1"; }

fixed=0
# fix_index_line <file> <lineno> <new-tail> — rewrite the text after " — " on one line
fix_index_line() {
  local f="$1" n="$2" tmp="$1.repobrain.tmp"
  NEWDESC="$3" awk -v n="$n" '
    NR == n { i = index($0, " — "); if (i > 0) $0 = substr($0, 1, i - 1) " — " ENVIRON["NEWDESC"] }
    { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

# canon <path> -> physical path with .. resolved (empty if parent dir missing)
canon() {
  local dir base
  dir=$(dirname "$1")
  base=$(basename "$1")
  (cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$base")
}

# resolve_link <containing-file> <target> <docroot> -> absolute path on stdout
# rc 0: resolved · rc 1: URL/anchor — nothing to check · rc 2: local target
# whose parent directory does not exist (a broken link, never a skip)
resolve_link() {
  local from="$1" target="$2" docroot="$3" out
  target="${target%%#*}"
  target="${target%% *}"                              # strip optional "title"
  [[ -z "$target" || "$target" == *"://"* ]] && return 1
  if [[ "$target" == /* ]]; then
    out=$(canon "$docroot/${target#/}")               # bundle-relative (OKF)
  else
    out=$(canon "$(dirname "$from")/$target")
  fi
  [[ -z "$out" ]] && return 2
  printf '%s\n' "$out"
}

# frontmatter helpers -----------------------------------------------------
fm_close_line() { # <file> -> line number of closing --- (or '')
  awk 'NR > 1 && /^---$/ { print NR; exit }' "$1"
}
fm_block() { # <file> <close-line> -> frontmatter body
  sed -n "2,$(( $2 - 1 ))p" "$1"
}
# desc_of <file> -> description value with its YAML quotes decoded ('' if
# none): a double-quoted value decodes \" and \\, a single-quoted one decodes
# ''. Trailing whitespace is trimmed, as it is from an index line. rc 3: a
# form the gate does not read — a block scalar (| or >), an unclosed quote,
# text after the closing quote, or another escape.
DESC_AWK='
/^description:/ {
  v = $0; sub(/^description:[ \t]*/, "", v); sub(/[ \t]+$/, "", v)
  q = substr(v, 1, 1)
  if (q == "|" || q == ">") exit 3
  if (q != "\"" && q != sq) { print v; exit }
  o = ""; n = length(v)
  for (i = 2; i <= n; i++) {
    c = substr(v, i, 1)
    if (q == "\"" && c == "\\") {
      c = substr(v, ++i, 1)
      if (c != "\"" && c != "\\") exit 3
    } else if (c == q) {
      if (q == sq && substr(v, i + 1, 1) == sq) i++
      else if (i == n) { sub(/[ \t]+$/, "", o); print o; exit }
      else exit 3
    }
    o = o c
  }
  exit 3
}'
desc_of() {
  local close
  [[ "$(head -1 "$1" 2>/dev/null)" == "---" ]] || return 0
  close=$(fm_close_line "$1")
  [[ -z "$close" ]] && return 0
  fm_block "$1" "$close" | awk -v sq="'" "$DESC_AWK"
}
TODAY=$(date +%F)
lifecycle_stale() { # <file> -> reason when frontmatter marks the doc stale ('' otherwise)
  local close fm sa
  [[ "$(head -1 "$1" 2>/dev/null)" == "---" ]] || return 0
  close=$(fm_close_line "$1")
  [[ -z "$close" ]] && return 0
  fm=$(fm_block "$1" "$close")
  if printf '%s\n' "$fm" | grep -q '^status:[[:space:]]*deprecated'; then
    printf 'status: deprecated'
    return 0
  fi
  sa=$(printf '%s\n' "$fm" | grep -m1 '^stale_after:' \
    | sed -e 's/^stale_after:[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/"//g')
  [[ -n "$sa" && "$sa" < "$TODAY" ]] && printf 'stale_after: %s' "$sa"  # ISO dates sort lexically
  return 0
}

have_code=0
lang_has_code && have_code=1

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# ---------- declaration set: built once, on the first token to resolve ----------
DECLS="$WORK/decls" PKGS="$WORK/pkgs"
decls_built=0
build_declarations() {
  (( decls_built )) && return 0
  decls_built=1
  if ! ( set -o pipefail; lang_declarations | sort -u > "$WORK/decl-all" ); then
    echo "check-repo-brain: internal scanner error — the declaration scan failed; treating the run as inconclusive" >&2
    exit 2
  fi
  grep '^pkg:' "$WORK/decl-all" | sed 's/^pkg://' > "$PKGS"
  grep -v '^pkg:' "$WORK/decl-all" > "$DECLS"
  rm -f "$WORK/decl-all"
}

is_repo_pkg() { grep -qxF "$1" "$PKGS" 2>/dev/null; }

# repo_files — the repository's non-markdown files, NUL-separated. A git work
# tree lists them through git — the tracked files, those of its submodules
# included, then the untracked ones git does not ignore — which never walks
# build outputs or symlinked caches. A tracked file is in every checkout, CI
# included; an untracked file under one of the adapter's LANG_PRUNE_DIRS is an
# installed dependency or a build output that only this checkout has, so it is
# left out. Elsewhere find skips the directories that hold dependencies and
# build outputs.
repo_files() {
  local -a spec=(-- . ':(exclude,glob)**/*.md' ':(exclude,glob)**/vendor/**')
  local -a others=("${spec[@]}") prune=(-name .git -o -name vendor -o -name node_modules
    -o -name 'bazel-*' -o -name .venv -o -name venv -o -name __pycache__ -o -name .tox
    -o -name dist -o -name target)
  local d
  for d in $LANG_PRUNE_DIRS; do
    others+=(":(exclude,glob)**/$d/**")
    prune+=(-o -name "$d")
  done
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    { git ls-files -z --cached --recurse-submodules "${spec[@]}" 2>/dev/null \
        || git ls-files -z --cached "${spec[@]}" 2>/dev/null; } \
      && git ls-files -z --others --exclude-standard "${others[@]}" 2>/dev/null && return 0
  fi
  find . \( "${prune[@]}" \) -prune -o -type f ! -name '*.md' -print0
}

# repo_words — the repository's distinct words (runs of [A-Za-z0-9_.$]) in
# its non-markdown text files, one per line, read once per gate run and kept.
# grep ends every file's last line, so two files never fuse into one word, and
# skips binary files.
REPO_WORDS="$WORK/repo-words"
repo_words() {
  if [[ ! -f "$REPO_WORDS" ]]; then
    repo_files | xargs -0 grep -Ih -e '' -- 2>/dev/null | LC_ALL=C tr -cs 'A-Za-z0-9_.$' '\n' \
      | LC_ALL=C awk '!seen[$0]++' > "$REPO_WORDS"
  fi
  cat "$REPO_WORDS"
}

# resolve_words <tokens-file> — the tokens that occur as a whole word in any
# non-markdown repository file, one per line. A dotted token such as
# `Type.Method` matches any run of whole dot-separated parts of a word, as
# grep -w would match it, and a word that carries $ (a JavaScript identifier)
# also offers its $-free parts. A lookup in the word set is linear in the
# repository's size, where a fixed-string grep for hundreds of tokens is not.
resolve_words() {
  repo_words | LC_ALL=C awk -v list="$1" '
      BEGIN { while ((getline t < list) > 0) if (t != "") want[t] = 1 }
      {
        n = split($0, p, ".")
        for (i = 1; i <= n; i++) {
          s = p[i]
          if (s in want) { print s; delete want[s] }
          for (j = i + 1; j <= n; j++) {
            s = s "." p[j]
            if (s in want) { print s; delete want[s] }
          }
        }
        if (index($0, "$") > 0) {
          n = split($0, p, /[$.]/)
          for (i = 1; i <= n; i++) if (p[i] in want) { print p[i]; delete want[p[i]] }
        }
      }'
  return 0
}

# One fence-aware awk pass per bundle extracts everything Q2's doc scan needs:
#   P <file> <lineno>          — a file:line citation outside fences/URLs/globs
#   S <file> <lineno> <token>  — a backticked symbol-shaped token to resolve
# Tokens are then resolved as SETS (one grep against the declaration file, one
# pass over the repository for the whole unresolved batch) — never per token.
# Language-specific shapes arrive as -v variables: file_ext, file_re, sym_re, qual_re.
DOCSCAN_AWK='
FNR == 1 { fence = 0 }
{
  line = $0
  if (line ~ /^ ? ? ?(```|~~~)/) { fence = 1 - fence; next }
  if (fence) next
  gsub(/[A-Za-z][A-Za-z0-9+.\-]*:\/\/[^ \t)>]*/, "", line)
  pf = 0
  if (index(line, file_ext) > 0) {
    n = split(line, sp, /[^A-Za-z0-9_*\/.~-]+/)
    for (i = 1; i <= n; i++) {
      s = sp[i]
      sub(/\.+$/, "", s)
      if (s ~ /\*/) continue
      if (s ~ file_re) { pf = 1; break }
    }
  }
  if (!pf && line ~ /(^|[^A-Za-z0-9_])line [0-9]+/) pf = 1
  if (pf) print "P\t" FILENAME "\t" FNR
  if (index(line, "`") == 0) next
  if (index(line, "⚠") > 0) next
  if (index(line, "*(planned)*") > 0) next
  m = split(line, seg, /`/)
  for (i = 2; i <= m; i += 2) {
    t = seg[i]
    if (t !~ /[a-z]/ && (t !~ /[A-Z]/ || index(t, "_") == 0)) continue
    if (t ~ sym_re || t ~ qual_re)
      print "S\t" FILENAME "\t" FNR "\t" t
  }
}
'

# ---------- the scope: which docs a scoped run checks, and how far ----------
# A doc the scope lists (a doc the diff touches) gets every check. A doc that
# only cites the scope — its text names the basename of a listed file as a
# whole word, or it cites in backticks a word the change removes (a symbol the
# diff renames or deletes) — reports only what the scope can break in it: a
# doc link into a listed file, the backticked tokens that carry a removed
# word, and an index line to a listed doc (whose description the diff can
# change). Its other findings are the repository's state, for a
# whole-repository run.
# Every list below holds relative paths as find(1) prints them under a root.
SCOPE_DOCS="$WORK/scope-docs"      # every doc a scoped run reads
FULL_DOCS="$WORK/full-docs"        # the listed docs: every check
SCOPE_PATHS="$WORK/scope-paths"
BASENAMES="$WORK/basenames"
if (( SCOPED )); then
  sed -e 's|^\./||' -e '/^$/d' "$SCOPE_LIST" | LC_ALL=C sort -u > "$SCOPE_PATHS"
  sed 's|.*/||' "$SCOPE_PATHS" | LC_ALL=C sort -u > "$BASENAMES"
  for r in "${ROOTS[@]}"; do find "$r" -type f -name '*.md'; done | LC_ALL=C sort -u > "$WORK/all-docs"
  grep -xF -f "$SCOPE_PATHS" "$WORK/all-docs" > "$FULL_DOCS"
  {
    cat "$FULL_DOCS"
    if [[ -s "$BASENAMES" && -s "$WORK/all-docs" ]]; then
      tr '\n' '\0' < "$WORK/all-docs" | xargs -0 grep -lwF -f "$BASENAMES" 2>/dev/null
    fi
    if [[ -n "$WORDS_LIST" && -s "$WORDS_LIST" && -s "$WORK/all-docs" ]]; then
      tr '\n' '\0' < "$WORK/all-docs" \
        | xargs -0 awk -v file_ext="$LANG_FILE_EXT" -v file_re="$LANG_FILE_RE" \
                       -v sym_re="$LANG_SYMBOL_RE" -v qual_re="$LANG_QUALIFIED_RE" "$DOCSCAN_AWK" \
        | awk -F'\t' -v list="$WORDS_LIST" '
            BEGIN { while ((getline w < list) > 0) want[w] = 1 }
            $1 == "S" { if ($4 in want) { print $2; next }
                        n = split($4, part, "."); for (i = 1; i <= n; i++) if (part[i] in want) { print $2; next } }'
    fi
  } | LC_ALL=C sort -u > "$SCOPE_DOCS"
  if [[ -s "$SCOPE_DOCS" ]]; then
    echo "check-repo-brain: scope — $(wc -l < "$SCOPE_DOCS" | tr -d ' ') doc(s) to check" \
      "($(wc -l < "$FULL_DOCS" | tr -d ' ') touched, every check; the rest cite the scope, scope lines only)"
  else
    echo "check-repo-brain: scope — no doc in scope; doc checks skipped"
  fi
fi

# bundle_docs <docroot> [name] [full] — the docs a run checks under one root:
# every *.md (or every file of that name); on a scoped run only the docs in
# scope, or with "full" only the docs that get every check
bundle_docs() {
  local name="${2:-*.md}" list="$SCOPE_DOCS"
  [[ "${3:-}" == full ]] && list="$FULL_DOCS"
  if (( SCOPED )); then
    find "$1" -type f -name "$name" | grep -xF -f "$list"
  else
    find "$1" -type f -name "$name"
  fi
  return 0
}

# full_doc <doc> — exit 0 iff the doc gets every check
full_doc() { (( ! SCOPED )) || grep -qxF -- "$1" "$FULL_DOCS"; }

# link_path <containing-file> <target> <docroot> — the link's target as a
# repository-relative path, the title and anchor stripped and . and .. folded
# by text, so a target whose directory does not exist still has a path
link_path() {
  local t="${2%%#*}"
  t="${t%% *}"
  if [[ "$t" == /* ]]; then t="$3/${t#/}"; else t="$(dirname "$1")/$t"; fi
  printf '%s\n' "$t" | awk -F/ '{
    n = 0
    for (i = 1; i <= NF; i++) {
      if ($i == "" || $i == ".") continue
      if ($i == ".." && n > 0 && st[n] != "..") { n--; continue }
      st[++n] = $i
    }
    o = ""; for (i = 1; i <= n; i++) o = o (i > 1 ? "/" : "") st[i]; print o
  }'
}

# in_list <path> <list-file> — exit 0 iff the path is a line of the list
in_list() { grep -qxF -- "$1" "$2"; }

# ---------- Q2: code→docs edges (repo-wide, or the scope's code files on a
# scoped run; resolved from repo root, then the citing file's own
# sub-project) ----------
docroot_for_file() { # <file> -> docroot of the longest matching project dir
  local f="${1#./}" best="" i
  for i in "${!PROJS[@]}"; do
    local p="${PROJS[$i]}"
    [[ "$p" == "." ]] && { [[ -z "$best" ]] && best="${ROOTS[$i]}"; continue; }
    case "$f" in "$p"/*) best="${ROOTS[$i]}" ;; esac
  done
  printf '%s\n' "${best:-${ROOTS[0]}}"
}

# url_only <file> <lineno> <target> — exit 0 iff the target appears on that
# line only inside URL spans (a link to another repository's docs, not an edge)
url_only() {
  awk -v n="$2" -v t="$3" -v re="[A-Za-z][A-Za-z0-9+.-]*://[^ \t)>\"'\`]*" '
    NR == n { gsub(re, ""); found = index($0, t) > 0; exit }
    END { exit found }' "$1"
}

if (( have_code )); then
  while IFS= read -r hit; do
    file="${hit%%:*}"; rest="${hit#*:}"; line="${rest%%:*}"; target="${rest#*:}"
    [[ -f "$target" ]] && continue
    proj_ok=0
    for i in "${!PROJS[@]}"; do
      p="${PROJS[$i]}"; [[ "$p" == "." ]] && continue
      case "${file#./}" in "$p"/*) [[ -f "$p/$target" ]] && proj_ok=1 ;; esac
    done
    (( proj_ok )) && continue
    url_only "$file" "$line" "$target" && continue
    CUR_DOCROOT=$(docroot_for_file "$file")
    fail "[Q2] $file:$line — code edge points at missing $target"
  done < <(if (( SCOPED )); then
             lang_code_edges | awk -v list="$SCOPE_PATHS" '
               BEGIN { while ((getline l < list) > 0) s[l] = 1 }
               { f = substr($0, 1, index($0, ":") - 1); sub(/^\.\//, "", f); if (f in s) print }'
           else
             lang_code_edges
           fi | awk '!seen[$0]++')
fi

# ---------- per-bundle checks ----------
check_bundle() { # <project-dir> <docroot>
  local proj="$1" docroot="$2"
  CUR_DOCROOT="$docroot"
  local root_index="$docroot/index.md"
  local root_index_c
  root_index_c=$(canon "$root_index")
  # a scoped run skips a bundle that holds no doc in scope
  (( SCOPED )) && [[ -z "$(bundle_docs "$docroot")" ]] && return 0

  # --- Q1: transitive reachability from the bundle's root index ---
  local reachable="" visited="" queue=("$root_index")
  while (( ${#queue[@]} > 0 )); do
    local idx="${queue[0]}"; queue=("${queue[@]:1}")
    local idx_c; idx_c=$(canon "$idx")
    case "$visited" in *"$idx_c"$'\n'*) continue ;; esac
    visited="$visited$idx_c"$'\n'
    [[ -f "$idx" ]] || continue
    while IFS= read -r raw; do
      local t="${raw#](}"; t="${t%)}"
      [[ "$t" == *.md* ]] || continue
      local resolved
      resolved=$(resolve_link "$idx" "$t" "$docroot") || continue  # broken links are Q2's report
      reachable="$reachable$resolved"$'\n'
      [[ "$(basename "$resolved")" == "index.md" ]] && queue+=("$resolved")
    done < <(grep -oE '\]\([^)]+\)' "$idx" 2>/dev/null)
  done
  if [[ ! -f "$root_index" ]] && [[ -n "$(bundle_docs "$docroot" '*.md' full)" ]]; then
    fail "[Q1] $docroot — no index.md: the bundle has no map"
  fi
  while IFS= read -r doc; do
    [[ "$(basename "$doc")" == "log.md" ]] && continue   # its own Q7 ban reports it
    local c; c=$(canon "$doc")
    [[ "$c" == "$root_index_c" ]] && continue
    case "$reachable" in *"$c"$'\n'*) ;; *)
      fail "[Q1] $doc — orphan: not reachable from $root_index" ;;
    esac
  done < <(bundle_docs "$docroot" '*.md' full)

  # --- Q2: every doc link resolves (a missing parent directory is just as
  # broken as a missing file — only URLs/anchors are exempt); a doc that only
  # cites the scope reports only its links into a listed file ---
  while IFS= read -r md; do
    local full=0; full_doc "$md" && full=1
    while IFS= read -r raw; do
      local t="${raw#](}"; t="${t%)}"
      [[ "$t" == *.md* ]] || continue
      (( full )) || in_list "$(link_path "$md" "$t" "$docroot")" "$SCOPE_PATHS" || continue
      local resolved rc=0
      resolved=$(resolve_link "$md" "$t" "$docroot") || rc=$?
      (( rc == 1 )) && continue
      if (( rc == 2 )) || [[ ! -f "$resolved" ]]; then
        fail "[Q2] $md — link target does not exist: $t"
      fi
    done < <(grep -oE '\]\([^)]+\)' "$md" 2>/dev/null)
  done < <(bundle_docs "$docroot")

  # --- Q2: doc scan — file:line ban + docs→code symbol resolution.
  # One awk pass extracts; resolution is set-based (see DOCSCAN_AWK above). A
  # doc that only cites the scope keeps only its backticked removed words. ---
  local scan; scan=$(mktemp)
  if ! ( set -o pipefail
         bundle_docs "$docroot" | tr '\n' '\0' \
           | xargs -0 awk -v file_ext="$LANG_FILE_EXT" -v file_re="$LANG_FILE_RE" \
                          -v sym_re="$LANG_SYMBOL_RE" -v qual_re="$LANG_QUALIFIED_RE" \
                          "$DOCSCAN_AWK" > "$scan" ); then
    echo "check-repo-brain: internal scanner error — the doc scan failed in $docroot; treating the run as inconclusive" >&2
    rm -f "$scan"
    exit 2
  fi
  if (( SCOPED )); then
    awk -F'\t' -v full="$FULL_DOCS" -v words="${WORDS_LIST:-/dev/null}" '
      BEGIN { while ((getline l < full) > 0) f[l] = 1; while ((getline l < words) > 0) w[l] = 1 }
      ($2 in f) { print; next }
      $1 == "S" { if ($4 in w) { print; next }
                  n = split($4, part, "."); for (i = 1; i <= n; i++) if (part[i] in w) { print; next } }' "$scan" > "$scan.kept"
    mv -f "$scan.kept" "$scan"
  fi
  local f ln
  while IFS=$'\t' read -r _ f ln; do
    fail "[Q2] $f:$ln — cites a file path or line number (churn-prone coordinate)"
  done < <(grep $'^P\t' "$scan")
  if (( have_code )) && grep -q $'^S\t' "$scan"; then
    local toks check members unres bad
    toks=$(mktemp) check=$(mktemp) members=$(mktemp) unres=$(mktemp) bad=$(mktemp)
    build_declarations
    grep $'^S\t' "$scan" | cut -f4 | sort -u > "$toks"
    # tokens to resolve (external pkg.Sym exempt). A qualified token resolves
    # as the PAIR itself — the declaration set carries pkg.Ident / Type.Method
    # ownership pairs, so `retry.Nope` never rides on a Nope declared elsewhere.
    local t p m
    while IFS= read -r t; do
      case "$t" in
        *.*)
          p="${t%%.*}"
          case "$p" in
            [a-z]*) is_repo_pkg "$p" || continue ;;  # external package (stdlib, deps) — exempt
          esac
          printf '%s\t%s\n' "$t" "$t" ;;
        *) printf '%s\t%s\n' "$t" "$t" ;;
      esac
    done < "$toks" > "$check"
    cut -f2 "$check" | sort -u > "$members"
    grep -vxF -f "$DECLS" "$members" | grep -v '^$' > "$unres" || true
    if [[ -s "$unres" ]]; then
      # ONE pass over the repository for the whole unresolved batch
      local found; found=$(mktemp)
      resolve_words "$unres" | sort -u > "$found"
      grep -vxF -f "$found" "$unres" > "$bad" || true
      rm -f "$found"
    fi
    if [[ -s "$bad" ]]; then
      local full mem tok
      while IFS=$'\t' read -r full mem; do
        grep -qxF "$mem" "$bad" || continue
        while IFS=$'\t' read -r _ f ln tok; do
          [[ "$tok" == "$full" ]] \
            && fail "[Q2] $f:$ln — backticked \`$full\` does not resolve (${mem} not declared or found in the repo)"
        done < <(grep $'^S\t' "$scan")
      done < "$check"
    fi
    rm -f "$toks" "$check" "$members" "$unres" "$bad"
  fi
  rm -f "$scan"

  # --- Q3: root wiring (exact path; sub-roots may ride the repo-root index);
  # a scoped run leaves it to a whole-repository run ---
  if (( ! SCOPED )); then
    local rel="$docroot"
    [[ "$proj" != "." ]] && rel="${docroot#$proj/}"
    local claude="CLAUDE.md" agents="AGENTS.md"
    [[ "$proj" != "." ]] && { claude="$proj/CLAUDE.md"; agents="$proj/AGENTS.md"; }
    local wired_claude=0 wired_agents=0
    [[ -f "$claude" ]] && grep -qF -- "$rel/index.md" "$claude" && wired_claude=1
    [[ -f "$agents" ]] && grep -qF -- "$rel/index.md" "$agents" && wired_agents=1
    if (( ! wired_claude && ! wired_agents )); then
      local via_root=0
      if [[ "$proj" != "." && -n "$ROOT_BUNDLE" ]]; then
        grep -rqF -- "$docroot/index.md" "$ROOT_BUNDLE" --include='*.md' 2>/dev/null && via_root=1
      fi
      if (( ! via_root )); then
        fail "[Q3] $proj — neither $claude nor $agents references $rel/index.md"
      fi
    elif (( ! wired_agents )); then
      note "[Q3] $agents lacks the $rel/index.md routing reference — AGENTS.md-reading tools start blind"
    fi
  fi

  # --- Q7: bundle contract ---
  while IFS= read -r md; do
    local close fm key
    [[ "$(basename "$md")" == "log.md" ]] && continue    # its own Q7 ban reports it
    if [[ "$(basename "$md")" == "index.md" ]]; then
      local is_root=0
      [[ "$(canon "$md")" == "$root_index_c" ]] && is_root=1
      if [[ "$(head -1 "$md" 2>/dev/null)" != "---" ]]; then
        # bare index — conformant, except the root must carry okf_version
        (( is_root )) && fail "[Q7] $md — root index missing its okf_version frontmatter"
        continue
      fi
      close=$(fm_close_line "$md")
      if [[ -z "$close" ]]; then
        fail "[Q7] $md — unterminated frontmatter (no closing ---)"
        continue
      fi
      if (( ! is_root )); then
        fail "[Q7] $md — frontmatter on a sub-index (indexes stay bare; okf_version belongs to the root alone)"
        continue
      fi
      fm=$(fm_block "$md" "$close")
      local nver
      nver=$(printf '%s\n' "$fm" | grep -c '^okf_version:')
      if (( nver == 0 )); then
        fail "[Q7] $md — root index missing 'okf_version:'"
      elif (( nver > 1 )); then
        fail "[Q7] $md — duplicate okf_version keys (exactly one, valued \"0.2\")"
      elif ! printf '%s\n' "$fm" | grep -qx 'okf_version: "0.2"'; then
        fail "[Q7] $md — okf_version must be exactly \"0.2\" (the spec version the R9 profile is built on)"
      fi
      local extra
      extra=$(printf '%s\n' "$fm" | grep -E '^[A-Za-z_-]+:' | grep -v '^okf_version:' | head -1)
      [[ -n "$extra" ]] \
        && fail "[Q7] $md — root index frontmatter carries '${extra%%:*}:' (okf_version is the only allowed key)"
      continue
    fi
    if [[ "$(head -1 "$md" 2>/dev/null)" != "---" ]]; then
      fail "[Q7] $md — no frontmatter block (first line must be ---)"
      continue
    fi
    close=$(fm_close_line "$md")
    if [[ -z "$close" ]]; then
      fail "[Q7] $md — unterminated frontmatter (no closing ---)"
      continue
    fi
    fm=$(fm_block "$md" "$close")
    if printf '%s\n' "$fm" | grep -q '^related:'; then
      fail "[Q7] $md — 'related:' frontmatter key (links live in the body)"
    fi
    if printf '%s\n' "$fm" | grep -q '^type:'; then
      printf '%s\n' "$fm" | grep -qE '^type:[[:space:]]*(feature|architecture|guide)[[:space:]]*$' \
        || fail "[Q7] $md — 'type:' must be feature, architecture, or guide (R9 profile)"
    else
      fail "[Q7] $md — frontmatter missing 'type:'"
    fi
    if printf '%s\n' "$fm" | grep -q '^description:'; then
      local desc drc=0
      desc=$(desc_of "$md") || drc=$?
      if (( drc == 3 )); then
        fail "[Q7] $md — 'description:' is not one plain or quoted line (a block scalar, or an escape other than \\\" and \\\\, is not read)"
      elif [[ -z "$desc" ]]; then
        fail "[Q7] $md — empty 'description:' (it IS the doc's index line)"
      fi
    else
      fail "[Q7] $md — frontmatter missing 'description:'"
    fi
  done < <(bundle_docs "$docroot" '*.md' full)

  # --- Q7: drift check — index line text == target's description (⚠️ exempt;
  # --fix rewrites drifted lines after the read loop, never during it). An
  # index that only cites the scope checks only its lines to the touched docs,
  # whose description the diff can change. ---
  while IFS= read -r idx; do
    local lineno=0 line fixes="" ifull=0
    full_doc "$idx" && ifull=1
    while IFS= read -r line; do
      lineno=$((lineno + 1))
      case "$line" in *'⚠️'*) continue ;; esac
      printf '%s' "$line" | grep -qE '^- \[[^]]*\]\([^)]*\.md[^)]*\) — ' || continue
      local t; t=$(printf '%s' "$line" | sed -E 's/^- \[[^]]*\]\(([^)]*)\).*/\1/')
      local tail="${line#* — }"
      tail=$(printf '%s' "$tail" | sed -e 's/[[:space:]]*$//')
      (( ifull )) || in_list "$(link_path "$idx" "$t" "$docroot")" "$FULL_DOCS" || continue
      local resolved
      resolved=$(resolve_link "$idx" "$t" "$docroot") || continue  # broken links are Q2's report
      [[ -f "$resolved" ]] || continue
      local lc; lc=$(lifecycle_stale "$resolved")
      [[ -n "$lc" ]] \
        && note "[Q7] $idx:$lineno — $(basename "$resolved") is stale by lifecycle ($lc) but its index line carries no ⚠️ flag"
      local desc drc=0
      desc=$(desc_of "$resolved") || drc=$?
      (( drc )) && continue  # an unread form is the contract check's report
      [[ -z "$desc" ]] && continue
      if [[ "$tail" != "$desc" ]]; then
        if (( FIX )); then
          fixes="${fixes}${lineno}"$'\x1f'"${desc}"$'\n'
        else
          fail "[Q7] $idx:$lineno — index line drifted from $(basename "$resolved")'s description"
        fi
      fi
    done < "$idx"
    if [[ -n "$fixes" ]]; then
      local n d
      while IFS=$'\x1f' read -r n d; do
        [[ -z "$n" ]] && continue
        fix_index_line "$idx" "$n" "$d"
        fixed=$((fixed + 1))
        echo "  fixed: $idx:$n — index line rewritten from its target's description"
      done <<< "$fixes"
    fi
  done < <(bundle_docs "$docroot" index.md)

  # --- Q7: no log.md ---
  while IFS= read -r lg; do
    fail "[Q7] $lg — log.md is reserved for change history; docs describe current behavior"
  done < <(bundle_docs "$docroot" log.md full)
}

for i in "${!PROJS[@]}"; do
  check_bundle "${PROJS[$i]}" "${ROOTS[$i]}"
done

# ---------- summary ----------
(( fixed > 0 )) && echo "check-repo-brain: rewrote $fixed drifted index line(s)"
if (( violations > 0 )); then
  echo "check-repo-brain: $violations violation(s) — rules: <docroot>/conventions.md" >&2
  exit 1
fi
echo "check-repo-brain: clean (${ROOTS[*]})"
exit 0
