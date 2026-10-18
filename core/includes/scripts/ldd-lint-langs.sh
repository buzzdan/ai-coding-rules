# ==================== linter table ====================
# What the gap linter needs to know per language id: how a comment is written,
# which source files a directory count leaves out, and whether the
# repository's own linter holds the file-length limit. The same table is
# rendered into every plugin, so two plugins measure one file the same way.
# residue-exempt: the table names every language's linter and config file on
# purpose, the same in every rendering.
#
#   lint_comment_style <id>         c (// and /* */), d (also /+ +/) or hash (#)
#   lint_package_skip_re <id>       ERE over a relative path: source files a
#                                   directory count leaves out (an index module,
#                                   a package marker, generated stubs); "" for none
#   lint_file_length_rule <id>      "<rule> in <config file>" when a linter config
#                                   at the repository root names a file-length
#                                   rule on a line that is not a comment, else
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
    typescript|javascript) printf '%s' '(^|/)index\.[cm]?[jt]sx?$' ;;
  esac
  return 0
}

# _lint_names <ERE> <file>... — print the first file that matches the pattern
# on a line that is not a comment
_lint_names() {
  local re="$1" f; shift
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    grep -vE '^[[:space:]]*(#|//|;)' -- "$f" 2>/dev/null | grep -qE -- "$re" && { printf '%s' "$f"; return 0; }
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