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
#   LANG_PRUNE_DIRS      the dependency and build-output directory names, space-
#                        separated; the symbol fallback never reads an untracked
#                        file under one
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
LANG_PRUNE_DIRS="vendor"
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

# LANG_DECL_AWK reads the Go files that lang_declarations lists and takes no -v
# variables. It prints "pkg:<package>", each declared name, "<package>.<name>"
# and, for a method, "<Type>.<method>", one per line. The qualified forms make a
# qualified doc token resolve only against its real owner, never against a
# same-named member elsewhere.
LANG_DECL_AWK='
function emit(identifier) {
  print identifier
  if (package_name != "") print package_name "." identifier
}
function is_identifier(text) {
  return text ~ /^[A-Za-z_][A-Za-z0-9_]*$/
}
FNR == 1 { package_name = ""; in_group = "" }
in_group != "" {
  if ($0 ~ /^\)/) { in_group = ""; next }
  text = $0; sub(/^[ \t]+/, "", text)
  if (text ~ /^[A-Za-z_]/) {
    names = text; sub(/[ \t=([].*$/, "", names)
    count = split(names, parts, ",")
    for (i = 1; i <= count; i++) {
      name = parts[i]; gsub(/[ \t]/, "", name)
      if (is_identifier(name)) emit(name)
    }
  }
  next
}
/^package [A-Za-z_]/ {
  name = $0; sub(/^package /, "", name); sub(/[^A-Za-z0-9_].*$/, "", name)
  package_name = name; print "pkg:" name; next
}
/^(type|var|const) \(/ { in_group = "y"; next }
/^func \(/ {
  receiver = $0; sub(/^func \(/, "", receiver); sub(/\).*$/, "", receiver)
  gsub(/\*/, "", receiver); sub(/^[ \t]+/, "", receiver); sub(/[ \t]+$/, "", receiver)
  word_count = split(receiver, receiver_words, /[ \t]+/)
  receiver_type = receiver_words[word_count]
  sub(/\[.*$/, "", receiver_type)
  name = $0; sub(/^func \([^)]*\)[ \t]*/, "", name); sub(/[ \t([].*$/, "", name)
  if (is_identifier(name)) {
    emit(name)
    if (is_identifier(receiver_type)) print receiver_type "." name
  }
  next
}
/^func [A-Za-z_]/ {
  name = $0; sub(/^func /, "", name); sub(/[ \t([].*$/, "", name)
  if (is_identifier(name)) emit(name)
  next
}
/^(type|var|const) [A-Za-z_]/ {
  text = $0; sub(/^(type|var|const) /, "", text)
  names = text; sub(/[ \t=([].*$/, "", names)
  count = split(names, parts, ",")
  for (i = 1; i <= count; i++) {
    name = parts[i]; gsub(/[ \t]/, "", name)
    if (is_identifier(name)) emit(name)
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
