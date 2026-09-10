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
#   lang_declarations    stdout: "pkg:<name>" for every package/module; every
#                        declared identifier; and ownership pairs — "pkg.Ident"
#                        for the declaring package and "Type.Method" for the
#                        receiver — one per line (duplicates are fine)
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

# Go declarations: package names (pkg:<name>), every declared identifier, and
# ownership pairs — pkg.Ident for the declaring package, Type.Method for the
# receiver — from single-line and grouped type/var/const declarations,
# functions, and methods. The pairs let a qualified doc token resolve only
# against its actual owner, never against a same-named member elsewhere.
LANG_DECL_AWK='
function emit(id) {
  print id
  if (curpkg != "") print curpkg "." id
}
FNR == 1 { curpkg = ""; inblock = "" }
inblock != "" {
  if ($0 ~ /^\)/) { inblock = ""; next }
  s = $0; sub(/^[ \t]+/, "", s)
  if (s ~ /^[A-Za-z_]/) {
    t = s; sub(/[ \t=([].*$/, "", t)
    n = split(t, parts, ",")
    for (i = 1; i <= n; i++) {
      p = parts[i]; gsub(/[ \t]/, "", p)
      if (p ~ /^[A-Za-z_][A-Za-z0-9_]*$/) emit(p)
    }
  }
  next
}
/^package [A-Za-z_]/ { s = $0; sub(/^package /, "", s); sub(/[^A-Za-z0-9_].*$/, "", s); curpkg = s; print "pkg:" s; next }
/^(type|var|const) \(/ { inblock = "y"; next }
/^func \(/ {
  r = $0; sub(/^func \(/, "", r); sub(/\).*$/, "", r)
  gsub(/\*/, "", r); sub(/^[ \t]+/, "", r); sub(/[ \t]+$/, "", r)
  nr = split(r, rp, /[ \t]+/); rt = rp[nr]
  sub(/\[.*$/, "", rt)
  s = $0; sub(/^func \([^)]*\)[ \t]*/, "", s); sub(/[ \t([].*$/, "", s)
  if (s ~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
    emit(s)
    if (rt ~ /^[A-Za-z_][A-Za-z0-9_]*$/) print rt "." s
  }
  next
}
/^func [A-Za-z_]/ {
  s = $0; sub(/^func /, "", s); sub(/[ \t([].*$/, "", s)
  if (s ~ /^[A-Za-z_][A-Za-z0-9_]*$/) emit(s)
  next
}
/^(type|var|const) [A-Za-z_]/ {
  s = $0; sub(/^(type|var|const) /, "", s)
  t = s; sub(/[ \t=([].*$/, "", t)
  n = split(t, parts, ",")
  for (i = 1; i <= n; i++) {
    p = parts[i]; gsub(/[ \t]/, "", p)
    if (p ~ /^[A-Za-z_][A-Za-z0-9_]*$/) emit(p)
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
