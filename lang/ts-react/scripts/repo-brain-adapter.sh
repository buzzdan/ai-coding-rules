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
#   lang_project_dirs    stdout: one sub-project directory per line, repo root excluded
#   lang_has_code        exit 0 iff the repo holds at least one code file
#   lang_declarations    stdout: "pkg:<name>" for every package/module; every
#                        declared identifier; and ownership pairs — "mod.ident"
#                        for the declaring module and "Class.member" for the
#                        class — one per line (duplicates are fine)
#   lang_code_edges      stdout: "file:line:target" for every docs-path citation
#                        inside code files (grep -rno shape)
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
  done < <(find . -name "$LANG_PROJECT_MARKER" "${TS_PRUNE[@]}" 2>/dev/null | sort)
}

lang_has_code() {
  find . "${TS_CODE_FILES[@]}" "${TS_PRUNE[@]}" -print -quit 2>/dev/null | grep -q .
}

# TypeScript declarations. Column-0 declarations are top level (Prettier indents
# every body). Brace depth is tracked outside strings and comments so that the
# members of a class, interface, object type, enum or namespace — the lines one
# level inside its braces — are emitted as `Owner.member`, while lines deeper
# than that (method bodies, object literals, nested blocks) are skipped. A
# destructuring pattern or an export list may span lines; its names are
# collected until the closing bracket. Misses cost a false report, so the
# heuristics lean toward emitting.
LANG_DECL_AWK='
function emit(id) {
  print id
  if (mod != "") print mod "." id
  if (pkgdir != "" && pkgdir != mod) print pkgdir "." id
}
function ident(s) {
  if (match(s, /^[A-Za-z_$][A-Za-z0-9_$]*/)) return substr(s, RSTART, RLENGTH)
  return ""
}
function keyword(w) {
  return w == "if" || w == "else" || w == "for" || w == "while" || w == "do" || w == "switch" || \
         w == "case" || w == "default" || w == "return" || w == "break" || w == "continue" || \
         w == "try" || w == "catch" || w == "finally" || w == "throw" || w == "new" || w == "await" || \
         w == "yield" || w == "typeof" || w == "void" || w == "delete" || w == "import" || w == "export" || \
         w == "function" || w == "class" || w == "const" || w == "let" || w == "var" || w == "this" || \
         w == "super" || w == "constructor"
}
function names(list,   n, parts, i, p) {
  n = split(list, parts, ",")
  for (i = 1; i <= n; i++) {
    p = parts[i]
    sub(/^[ \t]+/, "", p); sub(/[ \t]+$/, "", p)
    sub(/^\.\.\./, "", p)
    sub(/^type[ \t]+/, "", p)
    if (p ~ /[ \t]as[ \t]/) sub(/^.*[ \t]as[ \t]+/, "", p)
    else if (index(p, ":") > 0) sub(/^[^:]*:[ \t]*/, "", p)
    sub(/[ \t]*=.*$/, "", p)
    gsub(/[][{}() \t]/, "", p)
    if (p == "default") continue
    if (p ~ /^[A-Za-z_$][A-Za-z0-9_$]*$/ && !keyword(p)) emit(p)
  }
}
function braces(t,   o, c) {
  if (t ~ /^[ \t]*(\/\/|\/\*|\*)/) return 0
  gsub(/"[^"]*"/, "", t)
  gsub(sq "[^" sq "]*" sq, "", t)
  gsub(/`[^`]*`/, "", t)
  sub(/\/\/.*$/, "", t)
  gsub(/\/\*.*\*\//, "", t)
  gsub(/[^{}]/, "", t)
  o = gsub(/\{/, "", t); c = gsub(/\}/, "", t)
  return o - c
}
function owner(name) { emit(name); curclass = name; classdepth = depth }
function advance() {
  depth += d
  if (curclass != "" && depth <= classdepth) curclass = ""
}
BEGIN { sq = sprintf("%c", 39) }
FNR == 1 {
  curclass = ""; classdepth = 0; depth = 0; destr = 0; buf = ""
  f = FILENAME; sub(/^\.\//, "", f)
  n = split(f, parts, "/")
  mod = parts[n]; sub(/\.tsx?$/, "", mod)
  pkgdir = ""
  if (n >= 2) pkgdir = parts[n - 1]
  if (mod == "index") { mod = pkgdir; pkgdir = "" }
  if (mod != "") print "pkg:" mod
  if (pkgdir != "") print "pkg:" pkgdir
}
{ line = $0; d = braces(line) }
destr {
  if (line ~ /^[ \t]*[}\]]/) { names(buf); buf = ""; destr = 0; advance(); next }
  if (line ~ /^(export|declare|abstract|async|function|class|interface|type|enum|const|let|var|namespace|import)[ \t]/) {
    names(buf); buf = ""; destr = 0
  } else { buf = buf "," line; advance(); next }
}
/^(export|declare|abstract|async|function|class|interface|type|enum|const|let|var|namespace)[ \t]/ { depth = 0; curclass = "" }
/^(export[ \t]+)?(default[ \t]+)?(declare[ \t]+)?(abstract[ \t]+)?class[ \t]+[A-Za-z_$]/ {
  s = line; sub(/^(export[ \t]+)?(default[ \t]+)?(declare[ \t]+)?(abstract[ \t]+)?class[ \t]+/, "", s)
  name = ident(s); if (name != "") owner(name)
  advance(); next
}
/^(export[ \t]+)?(default[ \t]+)?(declare[ \t]+)?(async[ \t]+)?function[ \t*]+[A-Za-z_$]/ {
  s = line; sub(/^(export[ \t]+)?(default[ \t]+)?(declare[ \t]+)?(async[ \t]+)?function[ \t*]+/, "", s)
  name = ident(s); if (name != "") emit(name)
  advance(); next
}
/^(export[ \t]+)?(declare[ \t]+)?(const|let|var)[ \t]+/ {
  s = line; sub(/^(export[ \t]+)?(declare[ \t]+)?(const|let|var)[ \t]+/, "", s)
  if (s ~ /^[[{]/) {
    if (match(s, /[]}][ \t]*=[^=>]/)) names(substr(s, 2, RSTART - 2))
    else { buf = substr(s, 2); destr = 1 }
  } else if (s ~ /^enum[ \t]+[A-Za-z_$]/) {
    sub(/^enum[ \t]+/, "", s); name = ident(s); if (name != "") owner(name)
  } else {
    name = ident(s); if (name != "") emit(name)
  }
  advance(); next
}
/^(export[ \t]+)?(declare[ \t]+)?(interface|enum|namespace|type)[ \t]+[A-Za-z_$]/ {
  s = line; sub(/^(export[ \t]+)?(declare[ \t]+)?(interface|enum|namespace|type)[ \t]+/, "", s)
  name = ident(s); if (name != "") owner(name)
  advance(); next
}
/^export[ \t]+(type[ \t]+)?\{/ {
  s = line; sub(/^export[ \t]+(type[ \t]+)?\{/, "", s)
  if (index(s, "}") > 0) { sub(/\}.*$/, "", s); names(s) }
  else { buf = s; destr = 1 }
  advance(); next
}
/^export[ \t]+\*[ \t]+as[ \t]+[A-Za-z_$]/ {
  s = line; sub(/^export[ \t]+\*[ \t]+as[ \t]+/, "", s)
  name = ident(s); if (name != "") emit(name)
  advance(); next
}
curclass != "" && depth == classdepth + 1 {
  s = line; sub(/^[ \t]+/, "", s)
  if (s == "" || s ~ /^(\/\/|\/\*|\*|\}|@|#|\[)/) { advance(); next }
  while (match(s, /^(export|public|private|protected|static|readonly|async|override|abstract|declare|accessor|get|set|const|let|var|function|type|interface|class|enum)[ \t]+[A-Za-z_$*#]/))
    sub(/^[a-z]+[ \t]+/, "", s)
  sub(/^\*[ \t]*/, "", s)
  name = ident(s)
  if (name != "") {
    rest = substr(s, length(name) + 1)
    if (rest ~ /^[ \t]*([(<:=?!;,]|$)/ && !keyword(name)) { emit(name); print curclass "." name }
  }
  advance(); next
}
{ advance() }
'

lang_declarations() {
  find . "${TS_CODE_FILES[@]}" "${TS_PRUNE[@]}" -print0 2>/dev/null \
    | xargs -0 awk "$LANG_DECL_AWK"
}

lang_code_edges() {
  grep -rnoE '(docs|\.ai|\.ainav)/[A-Za-z0-9._/-]+\.md' \
    --include='*.ts' --include='*.tsx' --exclude='*.d.ts' \
    --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build --exclude-dir=.next \
    --exclude-dir=coverage --exclude-dir=.git . 2>/dev/null
}
# ================== end language adapter: ts-react ==================
