#!/usr/bin/env bash
# Repo-brain conformance gate for the go-linter-driven-development plugin.
#
# Runs R9's mechanical falsifying questions over every doc root so CI — and
# developers without the plugin — can hold the documentation network's
# invariants. What it enforces is the R9 profile: a strict superset of OKF
# v0.2 (rules/R9-repo-brain.md is normative; <docroot>/conventions.md is the
# in-repo copy). Installed into target repos by the documentation skill's
# BOOTSTRAP pass (/wire-repo-brain).
#
# Usage:  bash scripts/check-repo-brain.sh [--fix] [repo-root]   (default: cwd)
# CI:     one line — bash scripts/check-repo-brain.sh
# --fix:  rewrite drifted index lines from each target doc's `description`
#         (the one mechanical repair; everything else stays report-only)
#
# Doc roots are discovered at the repo root AND at every sub-project (a
# directory holding the language's project marker — see the adapter below),
# using R9's order: .ai/ -> .ainav/ -> docs/.
#
# Language scope: the driver (everything outside the adapter block) is
# language-agnostic — Q1, Q3, Q7, doc links, the --fix rewriter. Everything
# that touches code — sub-project discovery, the declaration set, the
# code-edge grep, the file:line ban, the symbol token shapes — comes from the
# adapter block. This build carries the Go adapter; with no code files, the
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
#                        type/description; indexes carry NO frontmatter except
#                        the root index's lone okf_version (required there);
#                        no `related:` key; no log.md; every index line's text
#                        matches the target's `description` when it has one
#                        (⚠️ lines exempt; --fix rewrites drifted lines)
#
# Heuristics (documented, deliberate):
#   - links are inline-markdown only (`[name](path.md)`, optional "title"
#     stripped); reference-style links are not checked.
#   - docs→code checks backticked tokens shaped like the language's exported
#     identifiers (adapter: LANG_SYMBOL_RE, LANG_QUALIFIED_RE) that contain a
#     lowercase letter; other backticks (paths, flags, ALL-CAPS initialisms,
#     <placeholders>) are skipped.
#   - resolution is against a declaration set built ONCE per run from the
#     language's code files (adapter: lang_declarations). A token missing from
#     the set still resolves when it appears as a whole word in any
#     non-markdown repo file (config keys, alert names, test helpers). A
#     `pkg.Sym` whose package is not declared in this repo is external
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
#             2 usage error
#
# Uses only POSIX-portable tools: find, grep, sed, awk, head, sort, wc. No jq/python.
# awk programs avoid interval expressions ({m,n}) — mawk, Debian's default, rejects them.

set -u

FIX=0
if [[ "${1:-}" == "--fix" ]]; then
  FIX=1
  shift
fi
REPO_ROOT="${1:-$(pwd)}"
if [[ ! -d "$REPO_ROOT" ]]; then
  echo "check-repo-brain: not a directory: $REPO_ROOT" >&2
  exit 2
fi
cd "$REPO_ROOT" || exit 2

# ======================= language adapter: go =======================
# Everything language-specific lives between these two marker comments. The
# driver below calls only the lang_* functions and LANG_* variables defined
# here; a build of this gate for another language replaces this block and
# nothing else. The fixture matrix (check-repo-brain_test.sh) is the contract
# every adapter must pass.
#
# Contract:
#   LANG_PROJECT_MARKER  file whose directory is a sub-project with its own doc root
#   LANG_CODE_GLOB       find(1) -name pattern for the language's code files
#   LANG_FILE_EXT        substring that flags a possible file citation (cheap pre-check)
#   LANG_FILE_RE         awk regex a citation span must match to be banned
#   LANG_SYMBOL_RE       awk regex for a bare backticked symbol worth resolving
#   LANG_QUALIFIED_RE    awk regex for a package-qualified `pkg.Sym` token
#   lang_project_dirs    stdout: one sub-project directory per line, repo root excluded
#   lang_has_code        exit 0 iff the repo holds at least one code file
#   lang_declarations    stdout: "pkg:<name>" for every package/module, plus every
#                        declared identifier, one per line (duplicates are fine)
#   lang_code_edges      stdout: "file:line:target" for every docs-path citation
#                        inside code files (grep -rno shape)
#
# Go: sub-projects are go.mod directories; exported identifiers start with an
# upper-case letter; the declaration set covers single-line and grouped
# `type (`/`var (`/`const (` declarations, functions, and methods.
LANG_PROJECT_MARKER="go.mod"
LANG_CODE_GLOB='*.go'
LANG_FILE_EXT=".go"
LANG_FILE_RE='\\.go(:[0-9]+)?$'
LANG_SYMBOL_RE='^[A-Z][A-Za-z0-9]*$'
LANG_QUALIFIED_RE='^[A-Za-z][A-Za-z0-9_]*\\.[A-Z][A-Za-z0-9]*$'

lang_project_dirs() {
  local m p
  while IFS= read -r m; do
    p=$(dirname "$m"); p="${p#./}"
    [[ "$p" == "." || -z "$p" ]] && continue
    printf '%s\n' "$p"
  done < <(find . -name "$LANG_PROJECT_MARKER" -not -path '*/vendor/*' -not -path './.git/*' 2>/dev/null | sort)
}

lang_has_code() {
  find . -name "$LANG_CODE_GLOB" -not -path './vendor/*' -not -path '*/vendor/*' -not -path './.git/*' \
    -print -quit 2>/dev/null | grep -q .
}

# Go declarations: package names (pkg:<name>) plus every declared identifier —
# single-line and grouped type/var/const declarations, functions, methods.
LANG_DECL_AWK='
inblock != "" {
  if ($0 ~ /^\)/) { inblock = ""; next }
  s = $0; sub(/^[ \t]+/, "", s)
  if (s ~ /^[A-Za-z_]/) {
    t = s; sub(/[ \t=([].*$/, "", t)
    n = split(t, parts, ",")
    for (i = 1; i <= n; i++) {
      p = parts[i]; gsub(/[ \t]/, "", p)
      if (p ~ /^[A-Za-z_][A-Za-z0-9_]*$/) print p
    }
  }
  next
}
/^package [A-Za-z_]/ { s = $0; sub(/^package /, "", s); sub(/[^A-Za-z0-9_].*$/, "", s); print "pkg:" s; next }
/^(type|var|const) \(/ { inblock = "y"; next }
/^func \(/ {
  s = $0; sub(/^func \([^)]*\)[ \t]*/, "", s); sub(/[ \t([].*$/, "", s)
  if (s ~ /^[A-Za-z_][A-Za-z0-9_]*$/) print s
  next
}
/^func [A-Za-z_]/ {
  s = $0; sub(/^func /, "", s); sub(/[ \t([].*$/, "", s)
  if (s ~ /^[A-Za-z_][A-Za-z0-9_]*$/) print s
  next
}
/^(type|var|const) [A-Za-z_]/ {
  s = $0; sub(/^(type|var|const) /, "", s)
  t = s; sub(/[ \t=([].*$/, "", t)
  n = split(t, parts, ",")
  for (i = 1; i <= n; i++) {
    p = parts[i]; gsub(/[ \t]/, "", p)
    if (p ~ /^[A-Za-z_][A-Za-z0-9_]*$/) print p
  }
  next
}
'

lang_declarations() {
  find . -name "$LANG_CODE_GLOB" -not -path '*/vendor/*' -not -path './.git/*' -print0 2>/dev/null \
    | xargs -0 awk "$LANG_DECL_AWK"
}

lang_code_edges() {
  grep -rnoE '(docs|\.ai|\.ainav)/[A-Za-z0-9._/-]+\.md' \
    --include="$LANG_CODE_GLOB" --exclude-dir=vendor --exclude-dir=.git . 2>/dev/null
}
# ===================== end language adapter: go =====================

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

# resolve_link <containing-file> <target> <docroot> -> absolute path ('' for URLs/anchors)
resolve_link() {
  local from="$1" target="$2" docroot="$3"
  target="${target%%#*}"
  target="${target%% *}"                              # strip optional "title"
  [[ -z "$target" || "$target" == *"://"* ]] && return 0
  if [[ "$target" == /* ]]; then
    printf '%s\n' "$(canon "$docroot/${target#/}")"   # bundle-relative (OKF)
  else
    printf '%s\n' "$(canon "$(dirname "$from")/$target")"
  fi
}

# frontmatter helpers -----------------------------------------------------
fm_close_line() { # <file> -> line number of closing --- (or '')
  awk 'NR > 1 && /^---$/ { print NR; exit }' "$1"
}
fm_block() { # <file> <close-line> -> frontmatter body
  sed -n "2,$(( $2 - 1 ))p" "$1"
}
desc_of() { # <file> -> description value ('' if none)
  local close
  [[ "$(head -1 "$1" 2>/dev/null)" == "---" ]] || return 0
  close=$(fm_close_line "$1")
  [[ -z "$close" ]] && return 0
  fm_block "$1" "$close" | grep -m1 '^description:' \
    | sed -e 's/^description:[[:space:]]*//' -e 's/[[:space:]]*$//'
}

have_code=0
lang_has_code && have_code=1

# ---------- declaration set: built once, queried per token ----------
DECLS="" PKGS=""
if (( have_code )); then
  DECLS=$(mktemp) PKGS=$(mktemp) DECL_ALL=$(mktemp)
  trap 'rm -f "$DECLS" "$PKGS"' EXIT
  lang_declarations | sort -u > "$DECL_ALL"
  grep '^pkg:' "$DECL_ALL" | sed 's/^pkg://' > "$PKGS"
  grep -v '^pkg:' "$DECL_ALL" > "$DECLS"
  rm -f "$DECL_ALL"
fi

is_repo_pkg() { grep -qxF "$1" "$PKGS" 2>/dev/null; }

# One fence-aware awk pass per bundle extracts everything Q2's doc scan needs:
#   P <file> <lineno>          — a file:line citation outside fences/URLs/globs
#   S <file> <lineno> <token>  — a backticked symbol-shaped token to resolve
# Tokens are then resolved as SETS (one grep against the declaration file, one
# repo-wide word grep for the whole unresolved batch) — never per token.
# Language-specific shapes arrive as -v variables: file_ext, file_re, sym_re, qual_re.
DOCSCAN_AWK='
FNR == 1 { fence = 0 }
{
  line = $0
  if (line ~ /^ ? ? ?(```|~~~)/) { fence = 1 - fence; next }
  if (fence) next
  gsub(/[A-Za-z][A-Za-z0-9+.\-]*:\/\/[^ )>]*/, "", line)
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
    if (t !~ /[a-z]/) continue
    if (t ~ sym_re || t ~ qual_re)
      print "S\t" FILENAME "\t" FNR "\t" t
  }
}
'

# ---------- Q2: code→docs edges (repo-wide; resolved from repo root, then the
# citing file's own sub-project) ----------
docroot_for_file() { # <file> -> docroot of the longest matching project dir
  local f="${1#./}" best="" i
  for i in "${!PROJS[@]}"; do
    local p="${PROJS[$i]}"
    [[ "$p" == "." ]] && { [[ -z "$best" ]] && best="${ROOTS[$i]}"; continue; }
    case "$f" in "$p"/*) best="${ROOTS[$i]}" ;; esac
  done
  printf '%s\n' "${best:-${ROOTS[0]}}"
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
    if (( ! proj_ok )); then
      CUR_DOCROOT=$(docroot_for_file "$file")
      fail "[Q2] $file:$line — code edge points at missing $target"
    fi
  done < <(lang_code_edges)
fi

# ---------- per-bundle checks ----------
check_bundle() { # <project-dir> <docroot>
  local proj="$1" docroot="$2"
  CUR_DOCROOT="$docroot"
  local root_index="$docroot/index.md"
  local root_index_c
  root_index_c=$(canon "$root_index")

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
      local resolved; resolved=$(resolve_link "$idx" "$t" "$docroot")
      [[ -z "$resolved" ]] && continue
      reachable="$reachable$resolved"$'\n'
      [[ "$(basename "$resolved")" == "index.md" ]] && queue+=("$resolved")
    done < <(grep -oE '\]\([^)]+\)' "$idx" 2>/dev/null)
  done
  if [[ ! -f "$root_index" ]]; then
    fail "[Q1] $docroot — no index.md: the bundle has no map"
  fi
  while IFS= read -r doc; do
    [[ "$(basename "$doc")" == "log.md" ]] && continue   # its own Q7 ban reports it
    local c; c=$(canon "$doc")
    [[ "$c" == "$root_index_c" ]] && continue
    case "$reachable" in *"$c"$'\n'*) ;; *)
      fail "[Q1] $doc — orphan: not reachable from $root_index" ;;
    esac
  done < <(find "$docroot" -type f -name '*.md')

  # --- Q2: every doc link resolves ---
  while IFS= read -r md; do
    while IFS= read -r raw; do
      local t="${raw#](}"; t="${t%)}"
      [[ "$t" == *.md* ]] || continue
      local resolved; resolved=$(resolve_link "$md" "$t" "$docroot")
      [[ -z "$resolved" ]] && continue
      [[ -f "$resolved" ]] || fail "[Q2] $md — link target does not exist: $t"
    done < <(grep -oE '\]\([^)]+\)' "$md" 2>/dev/null)
  done < <(find "$docroot" -type f -name '*.md')

  # --- Q2: doc scan — file:line ban + docs→code symbol resolution.
  # One awk pass extracts; resolution is set-based (see DOCSCAN_AWK above). ---
  local scan; scan=$(mktemp)
  find "$docroot" -type f -name '*.md' -print0 2>/dev/null \
    | xargs -0 awk -v file_ext="$LANG_FILE_EXT" -v file_re="$LANG_FILE_RE" \
                   -v sym_re="$LANG_SYMBOL_RE" -v qual_re="$LANG_QUALIFIED_RE" \
                   "$DOCSCAN_AWK" > "$scan"
  local f ln
  while IFS=$'\t' read -r _ f ln; do
    fail "[Q2] $f:$ln — cites a file path or line number (churn-prone coordinate)"
  done < <(grep $'^P\t' "$scan")
  if (( have_code )) && grep -q $'^S\t' "$scan"; then
    local toks check members unres bad
    toks=$(mktemp) check=$(mktemp) members=$(mktemp) unres=$(mktemp) bad=$(mktemp)
    grep $'^S\t' "$scan" | cut -f4 | sort -u > "$toks"
    # full-token -> member-to-resolve (external pkg.Sym exempt)
    local t p m
    while IFS= read -r t; do
      case "$t" in
        *.*)
          p="${t%%.*}" m="${t#*.}"
          case "$p" in
            [a-z]*) is_repo_pkg "$p" || continue ;;  # external package (stdlib, deps) — exempt
          esac
          printf '%s\t%s\n' "$t" "$m" ;;
        *) printf '%s\t%s\n' "$t" "$t" ;;
      esac
    done < "$toks" > "$check"
    cut -f2 "$check" | sort -u > "$members"
    grep -vxF -f "$DECLS" "$members" > "$unres" || true
    if [[ -s "$unres" ]]; then
      # ONE repo-wide word grep for the whole unresolved batch
      local found; found=$(mktemp)
      grep -rIhoFw --exclude-dir=vendor --exclude-dir=.git --exclude='*.md' \
        -f "$unres" . 2>/dev/null | sort -u > "$found"
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

  # --- Q3: root wiring (exact path; sub-roots may ride the repo-root index) ---
  local rel="$docroot"
  [[ "$proj" != "." ]] && rel="${docroot#$proj/}"
  local claude="CLAUDE.md" agents="AGENTS.md"
  [[ "$proj" != "." ]] && { claude="$proj/CLAUDE.md"; agents="$proj/AGENTS.md"; }
  local wired_claude=0 wired_agents=0
  [[ -f "$claude" ]] && grep -q "$rel/index.md" "$claude" && wired_claude=1
  [[ -f "$agents" ]] && grep -q "$rel/index.md" "$agents" && wired_agents=1
  if (( ! wired_claude && ! wired_agents )); then
    local via_root=0
    if [[ "$proj" != "." && -n "$ROOT_BUNDLE" ]]; then
      grep -rq "$docroot/index.md" "$ROOT_BUNDLE" --include='*.md' 2>/dev/null && via_root=1
    fi
    if (( ! via_root )); then
      fail "[Q3] $proj — neither $claude nor $agents references $rel/index.md"
    fi
  elif (( ! wired_agents )); then
    note "[Q3] $agents lacks the $rel/index.md routing reference — AGENTS.md-reading tools start blind"
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
      printf '%s\n' "$fm" | grep -q '^okf_version:' \
        || fail "[Q7] $md — root index missing 'okf_version:'"
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
    for key in type description; do
      printf '%s\n' "$fm" | grep -q "^${key}:" \
        || fail "[Q7] $md — frontmatter missing '${key}:'"
    done
  done < <(find "$docroot" -type f -name '*.md')

  # --- Q7: drift check — index line text == target's description (⚠️ exempt;
  # --fix rewrites drifted lines after the read loop, never during it) ---
  while IFS= read -r idx; do
    local lineno=0 line fixes=""
    while IFS= read -r line; do
      lineno=$((lineno + 1))
      case "$line" in *'⚠️'*) continue ;; esac
      printf '%s' "$line" | grep -qE '^- \[[^]]*\]\([^)]*\.md[^)]*\) — ' || continue
      local t; t=$(printf '%s' "$line" | sed -E 's/^- \[[^]]*\]\(([^)]*)\).*/\1/')
      local tail="${line#* — }"
      tail=$(printf '%s' "$tail" | sed -e 's/[[:space:]]*$//')
      local resolved; resolved=$(resolve_link "$idx" "$t" "$docroot")
      [[ -n "$resolved" && -f "$resolved" ]] || continue
      local desc; desc=$(desc_of "$resolved")
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
  done < <(find "$docroot" -type f -name 'index.md')

  # --- Q7: no log.md ---
  while IFS= read -r lg; do
    fail "[Q7] $lg — log.md is reserved for change history; docs describe current behavior"
  done < <(find "$docroot" -type f -name 'log.md')
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
