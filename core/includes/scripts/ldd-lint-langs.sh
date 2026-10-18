# ==================== linter table ====================
# What the gap linter needs to know per language id: how a comment is written,
# which source files a directory count leaves out, and where the repository's
# own linter sets a file-length limit. The same table is rendered into every
# plugin, so two plugins measure one file the same way.
# residue-exempt: the table names every language's linter and config file on
# purpose, the same in every rendering.
#
#   lint_comment_style <id>         c (// and /* */), d (also /+ +/) or hash (#)
#   lint_package_skip_re <id>       ERE over a relative path: source files a
#                                   directory count leaves out (an index module,
#                                   a package marker, generated stubs); "" for none
#   lint_file_length_config <id>    one line, from the repository root:
#                                   covered TAB <max> TAB <skip-comments 0|1> TAB
#                                     <skip-blank 0|1> TAB <rule and file>
#                                   unreadable TAB <rule and file>
#                                   none
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

# _lint_window <key ERE> <file> — the key's line and the lines after it, up to
# the next rule entry or 15 lines, joined by spaces; one window per match. The
# patterns reach awk as strings, so they use bracket expressions, never
# backslash escapes, which awk -v would rewrite.
_lint_window() {
  awk -v key="$1" -v q="'" '
    BEGIN {
      entry = "^[[:space:]]*-[[:space:]]*[{]?[[:space:]]*name:"
      qkey = "^[[:space:]]*[\"" q "][^\"" q "]+[\"" q "][[:space:]]*:"
    }
    function flush() { if (w != "") print w; w = ""; n = 0 }
    {
      if (n > 0 && ($0 ~ entry || $0 ~ qkey) && $0 !~ key) flush()
      if ($0 ~ key) { flush(); n = 1; w = $0; next }
      if (n > 0) { w = w " " $0; if (++n > 15) flush() }
    }
    END { flush() }
  ' "$2"
}

# _lint_number <ERE ending in the number> <text> — the first match's digits
_lint_number() {
  printf '%s\n' "$2" | awk -v re="$1" 'match($0, re) { v = substr($0, RSTART, RLENGTH); sub(/.*[^0-9]/, "", v); print v; exit }'
}

# _lint_off <text> — exit 0 when the rule in the window is switched off
_lint_off() {
  printf '%s\n' "$1" | grep -qE "max-lines[\"']?[[:space:]]*:[[:space:]]*[[]?[[:space:]]*[\"']?(off|0)([^0-9]|$)"
}

_lint_config_go() {
  local f w max sc sb unread=""
  for f in .golangci.yaml .golangci.yml .golangci.toml .golangci.json; do
    [[ -f "$f" ]] || continue
    grep -q 'file-length-limit' "$f" 2>/dev/null || continue
    case "$f" in *.toml|*.json) unread="revive file-length-limit in $f"; continue ;; esac
    while IFS= read -r w; do
      [[ "$w" =~ disabled:[[:space:]]*true ]] && continue
      max=$(_lint_number 'max:[[:space:]]*[0-9]+' "$w")
      [[ -z "$max" ]] && max=$(_lint_number 'arguments:[[:space:]]*[[][[:space:]]*[0-9]+' "$w")
      [[ -z "$max" ]] && max=$(_lint_number 'arguments:[[:space:]]*-[[:space:]]*[0-9]+' "$w")
      if [[ -z "$max" ]]; then unread="revive file-length-limit in $f"; continue; fi
      (( max > 0 )) || continue
      sc=0; sb=0
      [[ "$w" =~ skip-comments:[[:space:]]*true ]] && sc=1
      [[ "$w" =~ skip-blank-lines:[[:space:]]*true ]] && sb=1
      printf 'covered\t%s\t%s\t%s\trevive file-length-limit in %s\n' "$max" "$sc" "$sb" "$f"
      return 0
    done < <(_lint_window "name:[[:space:]]*[\"']?file-length-limit" "$f")
  done
  [[ -n "$unread" ]] && { printf 'unreadable\t%s\n' "$unread"; return 0; }
  printf 'none\n'
}

_lint_config_eslint() {
  local f w max sc sb
  for f in eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts eslint.config.mts eslint.config.cts \
           .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml; do
    [[ -f "$f" ]] || continue
    grep -q 'max-lines' "$f" 2>/dev/null || continue
    # sonarjs/max-lines counts lines of code: blank and comment-only lines are skipped.
    while IFS= read -r w; do
      w="${w%%]*}"
      _lint_off "$w" && continue
      max=$(_lint_number 'maximum[[:space:]]*:[[:space:]]*[0-9]+' "$w")
      printf 'covered\t%s\t1\t1\tsonarjs/max-lines in %s\n' "${max:-1000}" "$f"
      return 0
    done < <(_lint_window "sonarjs/max-lines[\"']?[[:space:]]*:" "$f")
    # ESLint's own max-lines counts every line unless skipComments or skipBlankLines say otherwise.
    while IFS= read -r w; do
      w="${w%%]*}"
      _lint_off "$w" && continue
      max=$(_lint_number '[^a-zA-Z]max[[:space:]]*:[[:space:]]*[0-9]+' "$w")
      [[ -z "$max" ]] && max=$(_lint_number "(error|warn|[12])[\"']?[[:space:]]*,[[:space:]]*[0-9]+" "$w")
      sc=0; sb=0
      [[ "$w" =~ skipComments[[:space:]]*:[[:space:]]*true ]] && sc=1
      [[ "$w" =~ skipBlankLines[[:space:]]*:[[:space:]]*true ]] && sb=1
      printf 'covered\t%s\t%s\t%s\tmax-lines in %s\n' "${max:-300}" "$sc" "$sb" "$f"
      return 0
    done < <(_lint_window "(^|[^/A-Za-z-])[\"']?max-lines[\"']?[[:space:]]*:" "$f")
  done
  printf 'none\n'
}

_lint_config_python() {
  local f line max unread=""
  for f in pyproject.toml .pylintrc pylintrc setup.cfg tox.ini; do
    [[ -f "$f" ]] || continue
    line=$(grep -E '^[[:space:]]*max-module-lines[[:space:]]*=' "$f" 2>/dev/null | head -1)
    [[ -n "$line" ]] || continue
    max=$(_lint_number "=[[:space:]]*[\"']?[0-9]+" "$line")
    if [[ -z "$max" ]]; then unread="pylint max-module-lines in $f"; continue; fi
    (( max > 0 )) || continue
    # pylint counts every line of the module.
    printf 'covered\t%s\t0\t0\tpylint max-module-lines in %s\n' "$max" "$f"
    return 0
  done
  [[ -n "$unread" ]] && { printf 'unreadable\t%s\n' "$unread"; return 0; }
  printf 'none\n'
}

lint_file_length_config() {
  case "$1" in
    go)                    _lint_config_go ;;
    typescript|javascript) _lint_config_eslint ;;
    python)                _lint_config_python ;;
    *)                     printf 'none\n' ;;
  esac
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