# ==================== language adapter: ts-react ====================
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
#   LANG_QUALIFIED_RE    awk regex for a module-qualified `mod.sym` token
#   LANG_PRUNE_DIRS      the dependency and build-output directory names, space-
#                        separated; the symbol fallback never reads an untracked
#                        file under one
#   lang_project_dirs    stdout: one sub-project directory per line, repo root excluded
#   lang_has_code        exit 0 iff the repo holds at least one code file
#   lang_declarations    stdout: "pkg:<name>" for every package/module; every
#                        declared identifier; and ownership pairs — "mod.ident"
#                        for the declaring module and "Class.member" for the
#                        class — one per line (duplicates are fine)
#   lang_code_edges      stdout: "file:line:target" for every docs-path citation
#                        inside code files (grep -rno shape)
#   lang_newline_files   stdout: the code files and project markers whose path
#                        holds a newline, NUL-separated. The four functions above
#                        skip every path that matches NL_PATH, the driver's
#                        pattern for a path that holds a newline.
#
# TypeScript + React: sub-projects are package.json directories outside
# node_modules; code files are *.ts and *.tsx outside node_modules, dist, build,
# .next and coverage, with *.d.ts left out (ambient typings, usually generated).
# A symbol worth resolving is PascalCase (a type, a component), camelCase with an
# inner capital (`useDevices`, `parsePolicy`) or UPPER_SNAKE (`DEFAULT_ATTEMPTS`)
# — a lone lower-case word is prose, not a citation. The declaration set covers
# top-level functions, variables (every name a destructuring list binds),
# classes, interfaces, type aliases, enums, namespaces and export lists, plus the
# members of a class, interface, object type or enum as `Owner.member`. Every
# identifier is owned twice: by its module (the file stem; `index` takes its
# directory's name) and by the directory holding the file, so `retry.parsePolicy`
# resolves whether the function lives in retry/index.ts or retry/policy.ts.
LANG_PROJECT_MARKER="package.json"
LANG_PRUNE_DIRS="node_modules dist build .next coverage"
# The single-pattern form, for readers of the contract; the walkers below spell
# the two exact names because `*.ts*` also matches .tsv, .tsbuildinfo and
# Vitest's .tsx.snap files.
LANG_CODE_GLOB='*.ts*'
LANG_FILE_EXT=".ts"
LANG_FILE_RE='\\.tsx?(:[0-9]+)?$'
LANG_SYMBOL_RE='^([A-Z][A-Za-z0-9]*|[a-z][a-z0-9]*[A-Z][A-Za-z0-9]*|[A-Z][A-Z0-9_]*_[A-Z0-9_]*)$'
LANG_QUALIFIED_RE='^[A-Za-z_$][A-Za-z0-9_$]*\\.[A-Za-z_$][A-Za-z0-9_$]*$'

# find(1) tests shared by the three walkers: the code-file names and the pruned
# directories. Arrays, not a printed word list, so no pattern meets pathname
# expansion on its way into find.
TS_CODE_FILES=( '(' -name '*.ts' -o -name '*.tsx' ')' -not -name '*.d.ts' )
TS_PRUNE=( -not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/build/*'
           -not -path '*/.next/*' -not -path '*/coverage/*' -not -path '*/.git/*' )

lang_project_dirs() {
  local m p
  while IFS= read -r m; do
    p=$(dirname "$m"); p="${p#./}"
    [[ "$p" == "." || -z "$p" ]] && continue
    printf '%s\n' "$p"
  done < <(find . -name "$LANG_PROJECT_MARKER" "${TS_PRUNE[@]}" -not -path "$NL_PATH" 2>/dev/null | sort)
}

lang_has_code() {
  find . "${TS_CODE_FILES[@]}" "${TS_PRUNE[@]}" -not -path "$NL_PATH" -print -quit 2>/dev/null | grep -q .
}

# LANG_DECL_AWK reads the TypeScript files that lang_declarations lists and
# takes no -v variables. It reads each line on its own and does not parse
# TypeScript. For a file that has lines, it prints "pkg:<module>" and
# "pkg:<directory>" when the path has them. It prints the names it finds, also
# qualified by the module and by the directory, and "<Owner>.<member>" for a
# member, one per line. A line at column 0 is top level, because Prettier
# indents every body. A member is a line one level inside the braces of a class,
# interface, object type, enum or namespace. The brace count skips strings on
# one line and lines that start with "//", "/*" or "*". Outside a block comment,
# a generator method such as "*entries() {" or "*[Symbol.iterator]() {" is not a
# comment line. A destructuring pattern or an export list can span lines. The
# program collects its names until a closing bracket at column 0, or until the
# closing bracket that balances the pattern. A missed name causes a false
# report, so the program prints a name when it is not sure.
LANG_DECL_AWK='
function emit(identifier) {
  print identifier
  if (module != "") print module "." identifier
  if (package_dir != "" && package_dir != module) print package_dir "." identifier
}
function ident(text, found) {
  if (!match(text, /^[A-Za-z_$][A-Za-z0-9_$]*/)) return 0
  found["name"] = substr(text, RSTART, RLENGTH)
  return 1
}
function keyword(word) {
  return word == "if" || word == "else" || word == "for" || word == "while" || word == "do" || word == "switch" || \
         word == "case" || word == "default" || word == "return" || word == "break" || word == "continue" || \
         word == "try" || word == "catch" || word == "finally" || word == "throw" || word == "new" || word == "await" || \
         word == "yield" || word == "typeof" || word == "void" || word == "delete" || word == "import" || word == "export" || \
         word == "function" || word == "class" || word == "const" || word == "let" || word == "var" || word == "this" || \
         word == "super" || word == "constructor"
}
function names(list,   count, parts, i, entry) {
  count = split(list, parts, ",")
  for (i = 1; i <= count; i++) {
    entry = parts[i]
    sub(/^[ \t]+/, "", entry); sub(/[ \t]+$/, "", entry)
    sub(/^\.\.\./, "", entry)
    sub(/^type[ \t]+/, "", entry)
    sub(/[ \t]*=.*$/, "", entry)
    if (entry ~ /[ \t]as[ \t]/) sub(/^.*[ \t]as[ \t]+/, "", entry)
    else if (index(entry, ":") > 0) sub(/^[^:]*:[ \t]*/, "", entry)
    gsub(/[][{}() \t]/, "", entry)
    if (entry == "default") continue
    if (entry ~ /^[A-Za-z_$][A-Za-z0-9_$]*$/ && !keyword(entry)) emit(entry)
  }
}
function generator(text) {
  return text ~ /^[ \t]*\*([A-Za-z_$#][A-Za-z0-9_$]*[(<]|\[)/
}
function comment_line(text) {
  return text ~ /^[ \t]*(\/\/|\/\*|\*)/ && (inside_comment || !generator(text))
}
function comment_open_after(text, open,   at) {
  while (1) {
    if (open) {
      at = index(text, "*/")
      if (at == 0) return 1
      text = substr(text, at + 2); open = 0
    } else {
      text = code_only(text)
      at = index(text, "/*")
      if (at == 0) return 0
      text = substr(text, at + 2); open = 1
    }
  }
}
function flush_collected() {
  names(collected)
  collected = ""; collecting = 0
}
function code_only(text) {
  gsub(/"[^"]*"/, "", text)
  gsub(sq "[^" sq "]*" sq, "", text)
  gsub(/`[^`]*`/, "", text)
  sub(/\/\/.*$/, "", text)
  gsub(/\/\*.*\*\//, "", text)
  return text
}
function brackets(text,   opens, closes) {
  if (comment_line(text)) return 0
  text = code_only(text)
  opens = gsub(/[[{]/, "", text); closes = gsub(/[]}]/, "", text)
  return opens - closes
}
function braces(text,   opens, closes) {
  if (comment_line(text)) return 0
  text = code_only(text)
  gsub(/[^{}]/, "", text)
  opens = gsub(/\{/, "", text); closes = gsub(/\}/, "", text)
  return opens - closes
}
function owner(name) { emit(name); current_class = name; class_depth = depth }
function advance() {
  depth += delta
  if (current_class != "" && depth <= class_depth) current_class = ""
}
BEGIN { sq = sprintf("%c", 39) }
FNR == 1 {
  collecting = 0; collected = ""
  current_class = ""; class_depth = 0; depth = 0; collect_depth = 0; open_comment = 0
  path = FILENAME; sub(/^\.\//, "", path)
  count = split(path, parts, "/")
  module = parts[count]; sub(/\.tsx?$/, "", module)
  package_dir = ""
  if (count >= 2) package_dir = parts[count - 1]
  if (module == "index") { module = package_dir; package_dir = "" }
  if (module != "") print "pkg:" module
  if (package_dir != "") print "pkg:" package_dir
}
{
  line = $0
  inside_comment = open_comment
  open_comment = comment_open_after(line, open_comment)
  delta = braces(line)
}
collecting {
  collect_depth += brackets(line)
  if (line ~ /^[]}]/ || (line ~ /^[ \t]*[]}]/ && collect_depth <= 0)) {
    flush_collected(); advance(); next
  }
  if (line ~ /^(export|declare|abstract|async|function|class|interface|type|enum|const|let|var|namespace|import)[ \t]/) {
    flush_collected()
  } else { collected = collected "," line; advance(); next }
}
/^(export|declare|abstract|async|function|class|interface|type|enum|const|let|var|namespace)[ \t]/ { depth = 0; current_class = "" }
/^(export[ \t]+)?(default[ \t]+)?(declare[ \t]+)?(abstract[ \t]+)?class[ \t]+[A-Za-z_$]/ {
  text = line; sub(/^(export[ \t]+)?(default[ \t]+)?(declare[ \t]+)?(abstract[ \t]+)?class[ \t]+/, "", text)
  if (ident(text, found)) owner(found["name"])
  advance(); next
}
/^(export[ \t]+)?(default[ \t]+)?(declare[ \t]+)?(async[ \t]+)?function[ \t*]+[A-Za-z_$]/ {
  text = line; sub(/^(export[ \t]+)?(default[ \t]+)?(declare[ \t]+)?(async[ \t]+)?function[ \t*]+/, "", text)
  if (ident(text, found)) emit(found["name"])
  advance(); next
}
/^(export[ \t]+)?(declare[ \t]+)?(const|let|var)[ \t]+/ {
  text = line; sub(/^(export[ \t]+)?(declare[ \t]+)?(const|let|var)[ \t]+/, "", text)
  if (text ~ /^[[{]/) {
    if (match(text, /[]}][ \t]*(:[^=]*)?=[^=>]/)) names(substr(text, 2, RSTART - 2))
    else { collected = substr(text, 2); collecting = 1; collect_depth = 1 + brackets(collected) }
  } else if (text ~ /^enum[ \t]+[A-Za-z_$]/) {
    sub(/^enum[ \t]+/, "", text); if (ident(text, found)) owner(found["name"])
  } else {
    if (ident(text, found)) emit(found["name"])
  }
  advance(); next
}
/^(export[ \t]+)?(declare[ \t]+)?(interface|enum|namespace|type)[ \t]+[A-Za-z_$]/ {
  text = line; sub(/^(export[ \t]+)?(declare[ \t]+)?(interface|enum|namespace|type)[ \t]+/, "", text)
  if (ident(text, found)) owner(found["name"])
  advance(); next
}
/^export[ \t]+(type[ \t]+)?\{/ {
  text = line; sub(/^export[ \t]+(type[ \t]+)?\{/, "", text)
  if (index(text, "}") > 0) { sub(/\}.*$/, "", text); names(text) }
  else { collected = text; collecting = 1; collect_depth = 1 + brackets(collected) }
  advance(); next
}
/^export[ \t]+\*[ \t]+as[ \t]+[A-Za-z_$]/ {
  text = line; sub(/^export[ \t]+\*[ \t]+as[ \t]+/, "", text)
  if (ident(text, found)) emit(found["name"])
  advance(); next
}
current_class != "" && depth == class_depth + 1 {
  text = line; sub(/^[ \t]+/, "", text)
  if (text == "" || comment_line(text) || text ~ /^(\}|@|#|\[)/) { advance(); next }
  while (match(text, /^(export|public|private|protected|static|readonly|async|override|abstract|declare|accessor|get|set|const|let|var|function|type|interface|class|enum)[ \t]+[A-Za-z_$*#]/))
    sub(/^[a-z]+[ \t]+/, "", text)
  sub(/^\*[ \t]*/, "", text)
  if (ident(text, found)) {
    name = found["name"]
    rest = substr(text, length(name) + 1)
    if (rest ~ /^[ \t]*([(<:=?!;,]|$)/ && !keyword(name)) { emit(name); print current_class "." name }
  }
  advance(); next
}
{ advance() }
'

lang_declarations() {
  find . "${TS_CODE_FILES[@]}" "${TS_PRUNE[@]}" -not -path "$NL_PATH" -print0 2>/dev/null \
    | xargs -0 awk "$LANG_DECL_AWK"
}

lang_code_edges() {
  grep -rnoE '(docs|\.ai|\.ainav)/[A-Za-z0-9._/-]+\.md' \
    --include='*.ts' --include='*.tsx' --exclude='*.d.ts' \
    --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build --exclude-dir=.next \
    --exclude-dir=coverage --exclude-dir=.git --exclude="$NL_PATH" --exclude-dir="$NL_PATH" . 2>/dev/null
}

lang_newline_files() {
  find . \( "${TS_CODE_FILES[@]}" -o -name "$LANG_PROJECT_MARKER" \) "${TS_PRUNE[@]}" -path "$NL_PATH" -print0 2>/dev/null
}
# ================== end language adapter: ts-react ==================
