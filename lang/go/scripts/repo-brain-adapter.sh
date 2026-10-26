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
#   lang_newline_files   stdout: the code files and project markers whose path
#                        holds a newline, NUL-separated. The four functions above
#                        skip every path that matches NL_PATH, the driver's
#                        pattern for a path that holds a newline.
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
  done < <(find . -name "$LANG_PROJECT_MARKER" -not -path '*/vendor/*' -not -path './.git/*' -not -path "$NL_PATH" 2>/dev/null | sort)
}

lang_has_code() {
  find . -name "$LANG_CODE_GLOB" -not -path './vendor/*' -not -path '*/vendor/*' -not -path './.git/*' \
    -not -path "$NL_PATH" -print -quit 2>/dev/null | grep -q .
}

# LANG_DECL_AWK reads the Go files that lang_declarations lists and takes no -v
# variables. It reads each line on its own and does not parse Go. It prints
# "pkg:<package>", the names it finds, "<package>.<name>" and "<Type>.<method>",
# one per line. It takes every name of a list such as "x, y" on a declaration
# line. Inside a grouped declaration it counts the brackets that are not in a
# string, a rune or a comment. It takes names only from a line that starts at
# bracket depth 0 and not in a raw string or a block comment: every name of a
# list on a line indented by one tab, and the first name of a deeper line. A
# group such as "var ()" closes on its own line.
LANG_DECL_AWK='
function emit(identifier) {
  print identifier
  if (package_name != "") print package_name "." identifier
}
function is_identifier(text) {
  return text ~ /^[A-Za-z_][A-Za-z0-9_]*$/
}
function emit_names(text, whole_list,   joined, list, count, parts, i, name) {
  joined = text
  gsub(/[ \t]*,[ \t]*/, ",", joined)
  list = ""
  if (whole_list && match(joined, /^[A-Za-z_][A-Za-z0-9_]*(,[A-Za-z_][A-Za-z0-9_]*)*,?([ \t=([]|$)/)) {
    list = substr(joined, 1, RLENGTH)
    sub(/,?[ \t=([]?$/, "", list)
  }
  if (list == "") {
    list = text; sub(/[ \t=([].*$/, "", list)
  }
  count = split(list, parts, ",")
  for (i = 1; i <= count; i++) {
    name = parts[i]; gsub(/[ \t]/, "", name)
    if (is_identifier(name)) emit(name)
  }
}
function scan_brackets(text,   count, i, character, quote) {
  count = length(text); quote = ""
  for (i = 1; i <= count; i++) {
    character = substr(text, i, 1)
    if (in_raw) { if (character == "`") in_raw = 0; continue }
    if (in_block) {
      if (character == "*" && substr(text, i + 1, 1) == "/") { in_block = 0; i++ }
      continue
    }
    if (quote != "") {
      if (character == "\\") i++
      else if (character == quote) quote = ""
      continue
    }
    if (character == "`") in_raw = 1
    else if (character == "\"" || character == "\047") quote = character
    else if (character == "/" && substr(text, i + 1, 1) == "/") break
    else if (character == "/" && substr(text, i + 1, 1) == "*") { in_block = 1; i++ }
    else if (character == "{" || character == "(" || character == "[") depth++
    else if (character == "}" || character == ")" || character == "]") { if (depth > 0) depth-- }
  }
}
FNR == 1 { package_name = ""; in_group = 0; depth = 0; in_raw = 0; in_block = 0 }
in_group {
  inside_literal = in_raw || in_block
  if (!inside_literal && $0 ~ /^\)/) { in_group = 0; depth = 0; next }
  entry_depth = depth
  scan_brackets($0)
  if (inside_literal || entry_depth > 0) next
  text = $0; sub(/^[ \t]+/, "", text)
  if (text ~ /^[A-Za-z_]/) emit_names(text, $0 ~ /^\t[A-Za-z_]/)
  next
}
/^package [A-Za-z_]/ {
  name = $0; sub(/^package /, "", name); sub(/[^A-Za-z0-9_].*$/, "", name)
  package_name = name; print "pkg:" name; next
}
/^(type|var|const) \(/ {
  if ($0 !~ /^(type|var|const) \([ \t]*\)/) { in_group = 1; depth = 0; in_raw = 0; in_block = 0 }
  next
}
/^func \(/ {
  receiver = $0; sub(/^func \(/, "", receiver); sub(/\).*$/, "", receiver)
  sub(/\[.*$/, "", receiver)
  gsub(/\*/, "", receiver); sub(/^[ \t]+/, "", receiver); sub(/[ \t]+$/, "", receiver)
  word_count = split(receiver, receiver_words, /[ \t]+/)
  receiver_type = receiver_words[word_count]
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
  emit_names(text, 1)
  next
}
'

lang_declarations() {
  find . -name "$LANG_CODE_GLOB" -not -path '*/vendor/*' -not -path './.git/*' \
    -not -path "$NL_PATH" -print0 2>/dev/null \
    | xargs -0 awk "$LANG_DECL_AWK"
}

lang_code_edges() {
  grep -rnoE '(docs|\.ai|\.ainav)/[A-Za-z0-9._/-]+\.md' \
    --include="$LANG_CODE_GLOB" --exclude-dir=vendor --exclude-dir=.git \
    --exclude="$NL_PATH" --exclude-dir="$NL_PATH" . 2>/dev/null
}

lang_newline_files() {
  find . \( -name "$LANG_CODE_GLOB" -o -name "$LANG_PROJECT_MARKER" \) -not -path '*/vendor/*' -not -path './.git/*' \
    -path "$NL_PATH" -print0 2>/dev/null
}
# ===================== end language adapter: go =====================
