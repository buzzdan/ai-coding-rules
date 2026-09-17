# ==================== language adapter: detected ====================
# Everything language-specific lives between these two marker comments. The
# driver below calls only the lang_* functions and LANG_* variables defined
# here. This is the generic plugin's adapter: it picks a language block from the
# repository's marker file at run time — go.mod selects Go, pyproject.toml
# (or setup.cfg / setup.py) selects Python — and a repository with neither keeps
# the structure checks (frontmatter, index, reachability, drift) while its
# code<->docs edges stay unverified. The fixture matrix
# (check-repo-brain_test.sh) is the contract every block must pass.
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

# The marker at the repo root wins; a marker below the root is the fallback, so a
# repository whose only Go module sits in a sub-directory is still checked as Go.
detect_language() {
  if [[ -f go.mod ]]; then printf 'go\n'; return; fi
  if [[ -f pyproject.toml || -f setup.cfg || -f setup.py ]]; then printf 'python\n'; return; fi
  if find . -name go.mod -not -path '*/vendor/*' -not -path './.git/*' -print -quit 2>/dev/null | grep -q .; then
    printf 'go\n'; return
  fi
  if find . \( -name pyproject.toml -o -name setup.cfg -o -name setup.py \) \
       -not -path '*/.venv/*' -not -path '*/node_modules/*' -not -path './.git/*' -print -quit 2>/dev/null | grep -q .; then
    printf 'python\n'; return
  fi
  printf 'unknown\n'
}

DETECTED_LANGUAGE=$(detect_language)
case "$DETECTED_LANGUAGE" in

go)
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
# functions, and methods.
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
;;

python)
# Python: sub-projects are pyproject.toml directories; a symbol worth resolving
# is CamelCase (a class) or snake_case with an underscore (a function or
# constant) — a lone lower-case word is prose, not a citation; the declaration
# set covers classes, functions, methods and module-level assignments. Every
# identifier is owned twice: by its module (the file name) and by the package
# directory holding the file, so `retry.parse_policy` resolves whether the
# function lives in retry/__init__.py or retry/policy.py.
LANG_PROJECT_MARKER="pyproject.toml"
LANG_CODE_GLOB='*.py'
LANG_FILE_EXT=".py"
LANG_FILE_RE='\\.py(:[0-9]+)?$'
LANG_SYMBOL_RE='^([A-Z][A-Za-z0-9_]*|[a-z_][a-z0-9_]*_[a-z0-9_]*)$'
LANG_QUALIFIED_RE='^[A-Za-z_][A-Za-z0-9_]*\\.[A-Za-z_][A-Za-z0-9_]*$'

py_prune() { # find(1) pruning shared by the three walkers
  printf '%s\n' -not -path '*/.venv/*' -not -path '*/venv/*' -not -path '*/node_modules/*' \
    -not -path '*/__pycache__/*' -not -path '*/site-packages/*' -not -path './.git/*'
}

lang_project_dirs() {
  local m p
  while IFS= read -r m; do
    p=$(dirname "$m"); p="${p#./}"
    [[ "$p" == "." || -z "$p" ]] && continue
    printf '%s\n' "$p"
  done < <(find . -name "$LANG_PROJECT_MARKER" $(py_prune) 2>/dev/null | sort)
}

lang_has_code() {
  find . -name "$LANG_CODE_GLOB" $(py_prune) -print -quit 2>/dev/null | grep -q .
}

LANG_DECL_AWK='
function emit(id) {
  print id
  if (mod != "") print mod "." id
  if (pkgdir != "" && pkgdir != mod) print pkgdir "." id
}
function keyword(w) {
  return w == "if" || w == "else" || w == "elif" || w == "try" || w == "except" || w == "finally" || \
         w == "for" || w == "while" || w == "with" || w == "return" || w == "import" || w == "from" || \
         w == "class" || w == "def" || w == "pass" || w == "raise" || w == "del" || w == "global" || \
         w == "nonlocal" || w == "assert" || w == "lambda" || w == "yield" || w == "match" || w == "case"
}
FNR == 1 {
  curclass = ""
  f = FILENAME; sub(/^\.\//, "", f)
  n = split(f, parts, "/")
  mod = parts[n]; sub(/\.py$/, "", mod)
  pkgdir = ""
  if (n >= 2) pkgdir = parts[n - 1]
  if (mod == "__init__") { mod = pkgdir; pkgdir = "" }
  if (mod != "") print "pkg:" mod
  if (pkgdir != "") print "pkg:" pkgdir
}
/^class [A-Za-z_]/ {
  s = $0; sub(/^class /, "", s); sub(/[^A-Za-z0-9_].*$/, "", s)
  emit(s); curclass = s; next
}
/^(async )?def [A-Za-z_]/ {
  s = $0; sub(/^(async )?def /, "", s); sub(/[^A-Za-z0-9_].*$/, "", s)
  emit(s); curclass = ""; next
}
/^[ \t]+(async )?def [A-Za-z_]/ {
  if (curclass == "") next
  s = $0; sub(/^[ \t]+(async )?def /, "", s); sub(/[^A-Za-z0-9_].*$/, "", s)
  emit(s); print curclass "." s; next
}
/^[A-Za-z_][A-Za-z0-9_]*([ \t]*,[ \t]*[A-Za-z_][A-Za-z0-9_]*)*[ \t]*(:[^=]*)?=[^=]/ {
  t = $0; sub(/[ \t]*(:[^=]*)?=.*$/, "", t)
  n = split(t, parts, ",")
  for (i = 1; i <= n; i++) {
    p = parts[i]; gsub(/[ \t]/, "", p)
    if (p ~ /^[A-Za-z_][A-Za-z0-9_]*$/ && !keyword(p)) emit(p)
  }
  curclass = ""; next
}
'

lang_declarations() {
  find . -name "$LANG_CODE_GLOB" $(py_prune) -print0 2>/dev/null \
    | xargs -0 awk "$LANG_DECL_AWK"
}

lang_code_edges() {
  grep -rnoE '(docs|\.ai|\.ainav)/[A-Za-z0-9._/-]+\.md' \
    --include="$LANG_CODE_GLOB" --exclude-dir=.venv --exclude-dir=venv --exclude-dir=node_modules \
    --exclude-dir=__pycache__ --exclude-dir=site-packages --exclude-dir=.git . 2>/dev/null
}
;;

*)
# No supported marker: the structure checks run, the code<->docs checks are
# skipped, and the first output line says so, so a clean exit is never read as
# "the edges were verified".
echo "check-repo-brain: no supported language marker (go.mod, pyproject.toml) — structure checks only; code<->docs edges are unverified"
LANG_PROJECT_MARKER="go.mod or pyproject.toml"
LANG_CODE_GLOB='*.no-source-files-for-an-unknown-language'
LANG_FILE_EXT=".no-source-files-for-an-unknown-language"
LANG_FILE_RE='^$'
LANG_SYMBOL_RE='^$'
LANG_QUALIFIED_RE='^$'
lang_project_dirs() { :; }
lang_has_code() { return 1; }
lang_declarations() { :; }
lang_code_edges() { :; }
;;
esac
# ================== end language adapter: detected ==================