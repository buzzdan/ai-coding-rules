# ==================== linter table ====================
# What the gap linter needs to know per language id: how a comment is written,
# which source files a directory count leaves out, and whether the
# repository's own linter holds the file-length limit. The same table is
# rendered into every plugin, so two plugins measure one file the same way.
# residue-exempt: the table names every language's linter and config file on
# purpose, the same in every rendering.
#
#   lint_comment_style <id>         c (// and /* */), d (also /+ +/) or hash (#)
#   lint_strip_comments <style> <file>  the file with every comment removed and
#                                   string literals kept, one output line per
#                                   input line: a comment-only line prints empty.
#                                   Styles: c, d, hash (# and triple-quoted
#                                   strings), ini (# and a leading ;)
#   lint_package_skip_re <id>       ERE over a relative path: source files a
#                                   directory count leaves out (an index module,
#                                   a package marker, generated stubs); "" for none
#   lint_file_length_rule <id>      "<rule> in <config file>" when a linter config
#                                   at the repository root names a file-length
#                                   rule outside a comment, else
#                                   nothing. A named rule belongs to the linter:
#                                   its limit, its counting and whether it is on
#                                   are the repository's decision.
#   lint_file_length_snippet <id> <max>  the linter setting that would hold the
#                                   limit, or the .ldd-lint.yaml entry when no
#                                   linter rule is known: text to propose

lint_comment_style() {
  case "$1" in
    python|ruby|shell) printf 'hash' ;;
    d)                 printf 'd' ;;
    *)                 printf 'c' ;;
  esac
}

lint_package_skip_re() {
  case "$1" in
    go)                    printf '%s' '(_gen|\.pb)\.go$' ;;
    python)                printf '%s' '(^|/)(__init__|conftest)\.py$|_pb2(_grpc)?\.py$' ;;
    typescript|javascript) printf '%s' '(^|/)index\.[cm]?[jt]sx?$|\.stories\.[cm]?[jt]sx?$' ;;
  esac
  return 0
}

# LINT_STRIP_AWK walks each line one character at a time. A quote opens a
# string that a comment marker cannot end; single and double quotes close at
# the end of the line, a backtick string (c and d) and a triple-quoted string
# (hash) run on. A block comment may open after code and run on. The awk uses
# substr and string compares only, so mawk, gawk and BSD awk read it alike.
LINT_STRIP_AWK='
BEGIN { bq = sprintf("%c", 96); sq = sprintf("%c", 39); dq = "\"" }
{
  line = $0; out = ""; n = length(line); i = 1
  if (q == dq || q == sq) q = ""
  while (i <= n) {
    if (inblock) {
      if (substr(line, i, length(closer)) == closer) { inblock = 0; i += length(closer); out = out " "; continue }
      i++; continue
    }
    ch = substr(line, i, 1)
    if (q != "") {
      if (ch == "\\" && (q == dq || q == sq)) { out = out substr(line, i, 2); i += 2; continue }
      if (substr(line, i, length(q)) == q) { out = out q; i += length(q); q = ""; continue }
      out = out ch; i++; continue
    }
    if (style == "hash" || style == "ini") {
      if (ch == "#") break
      if (style == "ini" && ch == ";" && out ~ /^[ \t]*$/) break
      three = substr(line, i, 3)
      if (style == "hash" && (three == dq dq dq || three == sq sq sq)) { q = three; out = out three; i += 3; continue }
    } else {
      two = substr(line, i, 2)
      if (two == "//") break
      if (two == "/*" || (style == "d" && two == "/+")) { inblock = 1; closer = (two == "/+") ? "+/" : "*/"; out = out " "; i += 2; continue }
      if (ch == bq) { q = bq; out = out ch; i++; continue }
    }
    if (ch == dq || ch == sq) { q = ch; out = out ch; i++; continue }
    out = out ch; i++
  }
  print out
}
'

lint_strip_comments() { # <style> <file>
  awk -v style="$1" "$LINT_STRIP_AWK" "$2"
}

# _lint_config_style <config file> — how that config format writes a comment
_lint_config_style() {
  case "$1" in
    *.yaml|*.yml|*.toml) printf 'hash' ;;
    *.cfg|*.ini|.pylintrc|pylintrc) printf 'ini' ;;
    *) printf 'c' ;;
  esac
}

# _lint_names <ERE> <file>... — print the first file whose text outside its
# comments matches the pattern
_lint_names() {
  local re="$1" f; shift
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    lint_strip_comments "$(_lint_config_style "$f")" "./$f" 2>/dev/null | grep -qE -- "$re" && { printf '%s' "$f"; return 0; }
  done
  return 1
}

lint_file_length_rule() {
  local f
  case "$1" in
    go)
      f=$(_lint_names 'file-length-limit' .golangci.yaml .golangci.yml .golangci.toml .golangci.json) \
        && printf 'revive file-length-limit in %s' "$f" ;;
    typescript|javascript)
      local configs=(eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts eslint.config.mts eslint.config.cts
                     .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml)
      if f=$(_lint_names 'sonarjs/max-lines([^-a-zA-Z]|$)' "${configs[@]}"); then
        printf 'sonarjs/max-lines in %s' "$f"
      elif f=$(_lint_names '(^|[^-/a-zA-Z])max-lines([^-a-zA-Z]|$)' "${configs[@]}"); then
        printf 'max-lines in %s' "$f"
      fi ;;
    python)
      f=$(_lint_names '^[[:space:]]*max-module-lines[[:space:]]*=' pyproject.toml .pylintrc pylintrc setup.cfg tox.ini) \
        && printf 'pylint max-module-lines in %s' "$f" ;;
  esac
  return 0
}

lint_file_length_snippet() {
  case "$1" in
    go)                    printf "revive in .golangci.yaml: - name: file-length-limit, arguments: [{max: %s, skip-comments: true, skip-blank-lines: true}]" "$2" ;;
    typescript|javascript) printf "the eslint config: 'sonarjs/max-lines': ['error', { maximum: %s }]" "$2" ;;
    python)                printf "pyproject.toml: [tool.pylint.format] max-module-lines = %s (pylint counts every line, comments and blank lines too)" "$2" ;;
    *)                     printf "no linter rule is known for %s; a .ldd-lint.yaml entry file_max_lines: %s would state this limit" "$1" "$2" ;;
  esac
}
# ================== end linter table ==================