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
LANG_PRUNE_DIRS=".venv venv __pycache__ site-packages .tox node_modules build dist .eggs"
LANG_CODE_GLOB='*.py'
LANG_FILE_EXT=".py"
LANG_FILE_RE='\\.py(:[0-9]+)?$'
LANG_SYMBOL_RE='^([A-Z][A-Za-z0-9_]*|[a-z_][a-z0-9_]*_[a-z0-9_]*)$'
LANG_QUALIFIED_RE='^[A-Za-z_][A-Za-z0-9_]*\\.[A-Za-z_][A-Za-z0-9_]*$'

# find(1) pruning shared by the three walkers, and grep's matching directory
# excludes for the code-edge scan, both built from LANG_PRUNE_DIRS. Arrays, so a
# pattern such as ./.git/* reaches find as it is and never expands against the tree.
PY_PRUNE=(-not -path './.git/*')
PY_EXCLUDE_DIRS=(--exclude-dir=.git)
for py_dir in $LANG_PRUNE_DIRS; do
  PY_PRUNE+=(-not -path "*/$py_dir/*")
  PY_EXCLUDE_DIRS+=("--exclude-dir=$py_dir")
done

lang_project_dirs() {
  local m p
  while IFS= read -r m; do
    p=$(dirname "$m"); p="${p#./}"
    [[ "$p" == "." || -z "$p" ]] && continue
    printf '%s\n' "$p"
  done < <(find . -name "$LANG_PROJECT_MARKER" "${PY_PRUNE[@]}" 2>/dev/null | sort)
}

lang_has_code() {
  find . -name "$LANG_CODE_GLOB" "${PY_PRUNE[@]}" -print -quit 2>/dev/null | grep -q .
}

# LANG_DECL_AWK reads the Python files that lang_declarations lists and takes no
# -v variables. It reads each line on its own and does not parse Python. For a
# file that has lines, it prints "pkg:<module>" and "pkg:<package directory>"
# when the path has them. It prints the names it finds, also qualified by the
# module and by the package directory, one per line. It skips a line that starts
# inside a string or inside brackets. After a class, it prints "<Class>.<name>"
# for each def at the indent of the class body. The class ends at the next
# column-0 line that is not blank, a comment or a decorator.
LANG_DECL_AWK='
function emit(identifier) {
  print identifier
  if (module != "") print module "." identifier
  if (package_dir != "" && package_dir != module) print package_dir "." identifier
}
function keyword(word) {
  return word == "if" || word == "else" || word == "elif" || word == "try" || word == "except" || word == "finally" || \
         word == "for" || word == "while" || word == "with" || word == "return" || word == "import" || word == "from" || \
         word == "class" || word == "def" || word == "pass" || word == "raise" || word == "del" || word == "global" || \
         word == "nonlocal" || word == "assert" || word == "lambda" || word == "yield" || word == "match" || word == "case"
}
function count_brackets(text,   copy) {
  copy = text; depth += gsub(/[[({]/, "", copy)
  copy = text; depth -= gsub(/[])}]/, "", copy)
  if (depth < 0) depth = 0
}
function scan_line(text,   at, character) {
  while (text != "") {
    if (in_string != "") {
      at = index(text, in_string)
      if (at == 0) return
      text = substr(text, at + 3); in_string = ""; continue
    }
    if (in_quote != "") {
      if (!match(text, in_quote == "\"" ? "[\\\\\"]" : "[\\\\\047]")) return
      if (substr(text, RSTART, 1) != in_quote) text = substr(text, RSTART + 2)
      else { text = substr(text, RSTART + 1); in_quote = "" }
      continue
    }
    if (!match(text, "[\"#\047]")) { count_brackets(text); return }
    count_brackets(substr(text, 1, RSTART - 1))
    character = substr(text, RSTART, 1); text = substr(text, RSTART)
    if (character == "#") return
    if (substr(text, 1, 3) == character character character) { in_string = substr(text, 1, 3); text = substr(text, 4) }
    else { in_quote = character; text = substr(text, 2) }
  }
}
FNR == 1 {
  current_class = ""; body_indent = ""; in_string = ""; in_quote = ""; depth = 0
  path = FILENAME; sub(/^\.\//, "", path)
  count = split(path, parts, "/")
  module = parts[count]; sub(/\.py$/, "", module)
  package_dir = ""
  if (count >= 2) package_dir = parts[count - 1]
  if (module == "__init__") { module = package_dir; package_dir = "" }
  if (module != "") print "pkg:" module
  if (package_dir != "") print "pkg:" package_dir
}
{
  if (in_string == "" && in_quote == "" && $0 ~ /^(class|(async )?def) [A-Za-z_]/) depth = 0
  continued = in_string != "" || in_quote != "" || depth > 0
  scan_line($0)
  if (in_quote != "" && substr($0, length($0), 1) != "\\") in_quote = ""
  if (continued) next
}
current_class != "" && $0 ~ /^[^ \t\r\f#@]/ { current_class = "" }
current_class != "" && body_indent == "" && $0 ~ /^[ \t]+[^ \t\r\f#]/ {
  body_indent = $0; sub(/[^ \t].*$/, "", body_indent)
}
/^class [A-Za-z_]/ {
  name = $0; sub(/^class /, "", name); sub(/[^A-Za-z0-9_].*$/, "", name)
  emit(name); current_class = name; body_indent = ""; next
}
/^(async )?def [A-Za-z_]/ {
  name = $0; sub(/^(async )?def /, "", name); sub(/[^A-Za-z0-9_].*$/, "", name)
  emit(name); next
}
/^[ \t]+(async )?def [A-Za-z_]/ {
  indent = $0; sub(/[^ \t].*$/, "", indent)
  if (current_class == "" || indent != body_indent) next
  name = $0; sub(/^[ \t]+(async )?def /, "", name); sub(/[^A-Za-z0-9_].*$/, "", name)
  emit(name); print current_class "." name; next
}
/^[A-Za-z_][A-Za-z0-9_]*[ \t]*(,[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*)*(:[^=]*)?=[^=]/ {
  targets = $0; sub(/[ \t]*(:[^=]*)?=.*$/, "", targets)
  count = split(targets, parts, ",")
  for (i = 1; i <= count; i++) {
    name = parts[i]; gsub(/[ \t]/, "", name)
    if (name ~ /^[A-Za-z_][A-Za-z0-9_]*$/ && !keyword(name)) emit(name)
  }
  next
}
'

lang_declarations() {
  find . -name "$LANG_CODE_GLOB" "${PY_PRUNE[@]}" -print0 2>/dev/null \
    | xargs -0 awk "$LANG_DECL_AWK"
}

lang_code_edges() {
  grep -rnoE '(docs|\.ai|\.ainav)/[A-Za-z0-9._/-]+\.md' \
    --include="$LANG_CODE_GLOB" "${PY_EXCLUDE_DIRS[@]}" . 2>/dev/null
}
;;

*)
# No supported marker: the structure checks run, the code<->docs checks are
# skipped, and the first output line says so, so a clean exit is never read as
# "the edges were verified".
echo "check-repo-brain: no supported language marker (go.mod, pyproject.toml) — structure checks only; code<->docs edges are unverified"
LANG_PROJECT_MARKER="go.mod or pyproject.toml"
LANG_PRUNE_DIRS=""
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