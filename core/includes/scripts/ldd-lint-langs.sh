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
#   lint_setup_files                one line per recommended config under the
#                                   plugin's setup/: file TAB the tool that checks it
#   lint_setup_check <file> <setup dir> <work dir>  run that tool's own check of
#                                   the file; exit 0 when the tool accepts it
#   lint_file_length_proposal <id>  what would hold the limit in the
#                                   repository's linter: the rule, named after
#                                   the plugin's recommended config under setup/
#                                   that sets it, or the .ldd-lint.yaml entry when
#                                   the language's linter has no such rule
#   lint_doctor_linter <id>         the linter the doctor compares for the
#                                   language; "" when the plugin recommends none
#   lint_doctor <id> <setup dir> <file>  compare the repository's linter with
#                                   the plugin's recommended config for the
#                                   language. <file> is a source file of the
#                                   language, for a linter that resolves its
#                                   settings per file. Prints tab-separated
#                                   records, never an empty field:
#                                     note TAB <text>
#                                     row TAB <linter> TAB <rule> TAB <state> TAB <recommended> TAB <current>
#                                   The rules: the ones the recommended config
#                                   enables, as the linter resolves it, beyond
#                                   the linter's default set, and the default
#                                   rules it names that the repository does not
#                                   run. state: runs ·
#                                   missing · limit differs · named (the rule is
#                                   named outside comments in the repository's
#                                   config; the linter was not asked) · cannot
#                                   verify: <why>. recommended and current: the
#                                   setting as the linter reports it, or "see
#                                   <file>: <key>" when the linter cannot report
#                                   it and a reader must look there, or "-"

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
  local re="$1" f p; shift
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    p="./$f"; [[ "$f" == /* ]] && p="$f"
    lint_strip_comments "$(_lint_config_style "$f")" "$p" 2>/dev/null | grep -qE -- "$re" && { printf '%s' "$f"; return 0; }
  done
  return 1
}

# The ESLint configs a repository root may hold. eslint.config.ldd.mjs is the
# plugin's recommended fragment: a repository that adopts it keeps it beside
# eslint.config.js and imports it.
LINT_ESLINT_CONFIGS=(eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts eslint.config.mts eslint.config.cts
                     eslint.config.ldd.mjs .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml)

lint_file_length_rule() {
  local f
  case "$1" in
    go)
      f=$(_lint_names 'file-length-limit' .golangci.yaml .golangci.yml .golangci.toml .golangci.json) \
        && printf 'revive file-length-limit in %s' "$f" ;;
    typescript|javascript)
      if f=$(_lint_names 'sonarjs/max-lines([^-a-zA-Z]|$)' "${LINT_ESLINT_CONFIGS[@]}"); then
        printf 'sonarjs/max-lines in %s' "$f"
      elif f=$(_lint_names '(^|[^-/a-zA-Z])max-lines([^-a-zA-Z]|$)' "${LINT_ESLINT_CONFIGS[@]}"); then
        printf 'max-lines in %s' "$f"
      fi ;;
    python)
      f=$(_lint_names '^[[:space:]]*max-module-lines[[:space:]]*=' pyproject.toml .pylintrc pylintrc setup.cfg tox.ini) \
        && printf 'pylint max-module-lines in %s' "$f" ;;
  esac
  return 0
}

lint_setup_files() {
  printf 'golangci.yaml\tgolangci-lint\n'
  printf 'ruff.toml\truff\n'
  printf 'eslint.config.ldd.mjs\tnode\n'
}

lint_setup_check() { # <file> <setup dir> <work dir>
  case "$1" in
    golangci.yaml)         golangci-lint config verify -c "$2/$1" ;;
    ruff.toml)             printf 'x = 1\n' > "$3/ldd_setup_check.py" && (cd "$3" && ruff check --no-cache --config "$2/$1" ldd_setup_check.py) ;;
    eslint.config.ldd.mjs) node --check "$2/$1" ;;
    *)                     return 2 ;;
  esac
}

lint_file_length_proposal() {
  case "$1" in
    go)                    printf "a setting to propose, never to add on your own: revive file-length-limit, as the plugin's setup/golangci.yaml sets it" ;;
    typescript|javascript) printf "a setting to propose, never to add on your own: sonarjs/max-lines, as the plugin's setup/eslint.config.ldd.mjs sets it" ;;
    python)                printf "ruff has no file-length rule, so this script holds the limit; a .ldd-lint.yaml entry file_max_lines: <n> states another" ;;
    *)                     printf "no linter rule is known for %s; a .ldd-lint.yaml entry file_max_lines: <n> states another limit" "$1" ;;
  esac
}

# ---------- doctor ----------
lint_doctor_linter() {
  case "$1" in
    go)                    printf 'golangci-lint' ;;
    python)                printf 'ruff' ;;
    typescript|javascript) printf 'eslint' ;;
  esac
  return 0
}

lint_doctor() { # <id> <setup dir> <file>
  local t; t=$(mktemp -d)
  case "$1" in
    go)                    _lint_doctor_golangci "$2/golangci.yaml" "$t" ;;
    python)                _lint_doctor_ruff "$2/ruff.toml" "$3" "$t" ;;
    typescript|javascript) _lint_doctor_eslint "$2/eslint.config.ldd.mjs" ;;
  esac
  rm -rf "$t"
}

_lint_doctor_cannot() { # <linter> <why>
  printf 'row\t%s\t-\tcannot verify: %s\t-\t-\n' "$1" "$2"
}

# _lint_first_error <file> — the first line of a linter's stderr that names an
# error, else its first line, on one line
_lint_first_error() {
  { grep -m1 -iE 'error' "$1" || head -1 "$1"; } | tr '\t' ' '
}

# _lint_doctor_sets <recommended> <default> <repository> <recommended config>
# — "rule TAB runs" or "rule TAB missing" for every rule the recommended set
# enables beyond the linter's default set, and for every default rule the
# recommended config names outside comments that the repository does not run.
# Each of the first three files holds one rule per line, sorted with LC_ALL=C.
_lint_doctor_sets() {
  local r
  { LC_ALL=C comm -23 "$1" "$2"
    LC_ALL=C comm -12 "$1" "$2" | LC_ALL=C comm -23 - "$3" | while IFS= read -r r; do
      _lint_names "(^|[^A-Za-z0-9_-])$r([^A-Za-z0-9_-]|\$)" "$4" >/dev/null && printf '%s\n' "$r"
    done; } \
    | LC_ALL=C sort -u | while IFS= read -r r; do
      if grep -qxF -- "$r" "$3"; then printf '%s\truns\n' "$r"; else printf '%s\tmissing\n' "$r"; fi
    done
}

# golangci-lint reports which linters a config enables, never their settings.
# A setting of the recommended config is "see <file>: <key>" on both sides.

# _lint_golangci_names <file> — the linter names of a "linters --json"
# output's Enabled list, sorted
_lint_golangci_names() {
  sed 's/"Disabled":.*//' "$1" | grep -oE '"name":"[^"]+"' | sed 's/^"name":"//; s/"$//' | LC_ALL=C sort -u
}

# _lint_golangci_tuned <config> <linter> — exit 0 when the config has a
# settings block for the linter
_lint_golangci_tuned() {
  lint_strip_comments hash "$1" | grep -qE -- "^[[:space:]]+$2:[[:space:]]*$"
}

# _lint_revive_rules <config> — "rule TAB 1" for a revive rule with
# arguments, "rule TAB 0" for one without, for every rule the config's revive
# block names
_lint_revive_rules() {
  lint_strip_comments hash "$1" | awk -v q="'" '
    function indent(s) { match(s, /^ */); return RLENGTH }
    /^[ \t]*$/ { next }
    inrev && indent($0) <= revind { inrev = 0; if (name != "") print name "\t0"; name = "" }
    /^[ \t]+revive:[ \t]*$/ { inrev = 1; revind = indent($0); next }
    !inrev { next }
    name != "" { print name "\t" ($0 ~ /^[ \t]+arguments:/ ? 1 : 0); name = "" }
    /^[ \t]*-[ \t]*name:[ \t]*/ { name = $0; sub(/^[ \t]*-[ \t]*name:[ \t]*/, "", name); gsub("[\"" q " \t]", "", name) }
    END { if (name != "") print name "\t0" }'
}

_lint_doctor_golangci() { # <recommended config> <work dir>
  local rec="$1" t="$2" cfg r state tuned rv cv here
  command -v golangci-lint >/dev/null 2>&1 || { _lint_doctor_cannot golangci-lint "golangci-lint is not installed"; return 0; }
  golangci-lint linters --json -c "$rec" > "$t/rec.json" 2> "$t/err" \
    || { _lint_doctor_cannot golangci-lint "the linter rejects $rec: $(_lint_first_error "$t/err")"; return 0; }
  golangci-lint linters --json --no-config > "$t/def.json" 2> "$t/err" \
    || { _lint_doctor_cannot golangci-lint "the linter fails with no config: $(_lint_first_error "$t/err")"; return 0; }
  # "path" is "" when the linter finds no config from this directory up
  cfg=$(golangci-lint config path --json 2>/dev/null | sed -n 's/.*"path":"\([^"]*\)".*/\1/p')
  if [[ -n "$cfg" ]]; then
    golangci-lint linters --json > "$t/repo.json" 2> "$t/err" \
      || { _lint_doctor_cannot golangci-lint "the linter rejects $cfg: $(_lint_first_error "$t/err")"; return 0; }
    printf 'note\tgolangci-lint, the repository config %s; the linter reports which linters run, not their settings\n' "$cfg"
    here="see $cfg"
  else
    cp "$t/def.json" "$t/repo.json"
    printf 'note\tgolangci-lint, no repository config: the linter runs its default set\n'
    here="the linter's default"
  fi
  _lint_golangci_names "$t/rec.json" > "$t/rec"
  _lint_golangci_names "$t/def.json" > "$t/def"
  _lint_golangci_names "$t/repo.json" > "$t/repo"
  _lint_doctor_sets "$t/rec" "$t/def" "$t/repo" "$rec" | while IFS=$'\t' read -r r state; do
    rv=-; cv=-
    if _lint_golangci_tuned "$rec" "$r"; then
      rv="see $rec: linters.settings.$r"
      [[ "$state" == runs && -n "$cfg" ]] && cv="see $cfg: linters.settings.$r, the linter's default when absent"
      [[ "$state" == runs && -z "$cfg" ]] && cv="the linter's default"
    fi
    printf 'row\tgolangci-lint\t%s\t%s\t%s\t%s\n' "$r" "$state" "$rv" "$cv"
  done
  grep -qxF revive "$t/rec" || return 0
  # The linter cannot say which revive rules run: a rule the repository's
  # config names outside comments is "named".
  _lint_revive_rules "$rec" | while IFS=$'\t' read -r r tuned; do
    rv=-; cv=-; state=missing
    grep -qxF revive "$t/repo" && [[ -n "$cfg" ]] \
      && _lint_names "name:[[:space:]]*[\"']?$r[\"']?([[:space:]]|$)" "$cfg" >/dev/null && state=named
    if [[ "$tuned" == 1 ]]; then
      rv="see $rec: linters.settings.revive.rules, name $r"
      [[ "$state" == named ]] && cv="$here: linters.settings.revive.rules, name $r"
    fi
    printf 'row\tgolangci-lint\trevive %s\t%s\t%s\t%s\n' "$r" "$state" "$rv" "$cv"
  done
}

# ruff reports the rules it runs and every setting, resolved per file.

# _lint_ruff_rules <file> — the rule codes of a --show-settings output's
# linter.rules.enabled list, sorted
_lint_ruff_rules() {
  awk '/^linter\.rules\.enabled = \[\]/ { exit }
       /^linter\.rules\.enabled = \[/ { f = 1; next }
       f && /^\]/ { exit }
       f' "$1" | grep -oE '\([A-Z]+[0-9]+\)' | tr -d '()' | LC_ALL=C sort -u
}

# _lint_ruff_value <file> <key> — the value of linter.<key> in a
# --show-settings output
_lint_ruff_value() {
  awk -v k="linter.$2" '$1 == k && $2 == "=" { print $3; exit }' "$1"
}

# _lint_ruff_setting <code> — the setting that holds the rule's limit
_lint_ruff_setting() {
  case "$1" in
    C901)    printf 'mccabe.max_complexity' ;;
    PLR0911) printf 'pylint.max_returns' ;;
    PLR0912) printf 'pylint.max_branches' ;;
    PLR0913) printf 'pylint.max_args' ;;
    PLR0915) printf 'pylint.max_statements' ;;
    PLR1702) printf 'pylint.max_nested_blocks' ;;
  esac
  return 0
}

_lint_doctor_ruff() { # <recommended config> <file> <work dir>
  local rec="$1" f="./$2" t="$3" sp r state key rv cv
  command -v ruff >/dev/null 2>&1 || { _lint_doctor_cannot ruff "ruff is not installed"; return 0; }
  [[ -n "$2" ]] || { _lint_doctor_cannot ruff "no source file to resolve the settings for"; return 0; }
  ruff check --no-cache --color never --show-settings --config "$rec" "$f" > "$t/rec.txt" 2> "$t/err" \
    || { _lint_doctor_cannot ruff "the linter rejects $rec: $(_lint_first_error "$t/err")"; return 0; }
  ruff check --no-cache --color never --show-settings --isolated "$f" > "$t/def.txt" 2> "$t/err" \
    || { _lint_doctor_cannot ruff "the linter fails with no config: $(_lint_first_error "$t/err")"; return 0; }
  ruff check --no-cache --color never --show-settings "$f" > "$t/repo.txt" 2> "$t/err" \
    || { _lint_doctor_cannot ruff "the linter rejects the repository's config: $(_lint_first_error "$t/err")"; return 0; }
  sp=$(sed -n 's/^Settings path: "\(.*\)"$/\1/p' "$t/repo.txt")
  sp="${sp#"$(pwd -P)"/}"; sp="${sp#"$(pwd)"/}"
  [[ -n "$sp" ]] || sp="no config file, the linter's defaults"
  printf 'note\truff, the settings resolved for %s from %s\n' "$2" "$sp"
  _lint_ruff_rules "$t/rec.txt" > "$t/rec"
  _lint_ruff_rules "$t/def.txt" > "$t/def"
  _lint_ruff_rules "$t/repo.txt" > "$t/repo"
  _lint_doctor_sets "$t/rec" "$t/def" "$t/repo" "$rec" | while IFS=$'\t' read -r r state; do
    rv=-; cv=-
    key=$(_lint_ruff_setting "$r")
    if [[ -n "$key" ]]; then
      rv="$key = $(_lint_ruff_value "$t/rec.txt" "$key")"
      if [[ "$state" == runs ]]; then
        cv="$key = $(_lint_ruff_value "$t/repo.txt" "$key")"
        [[ "$cv" == "$rv" ]] || state="limit differs"
      fi
    fi
    printf 'row\truff\t%s\t%s\t%s\t%s\n' "$r" "$state" "$rv" "$cv"
  done
}

# ESLint: the doctor does not run it; a rule the repository's config
# names outside comments is "named", and every setting is "see <file>: <key>".

# _lint_eslint_rules <config> — "rule TAB 1" for a rule set with options,
# "rule TAB 0" for one set by severity only, once per rule, in the order the
# config first sets it; a rule set to "off" (as for test files) is left out
_lint_eslint_rules() {
  lint_strip_comments c "$1" | awk -v q="'" '
    { line = $0; sub(/^[ \t]+/, "", line)
      if (substr(line, 1, 1) != q) next
      rest = substr(line, 2); i = index(rest, q); if (i == 0) next
      name = substr(rest, 1, i - 1); after = substr(rest, i + 1)
      if (substr(after, 1, 1) != ":") next
      sub(/^:[ \t]*/, "", after); c = substr(after, 1, 1)
      sev = after; sub(/^\[[ \t]*/, "", sev)
      if (substr(sev, 1, 5) == q "off" q || seen[name]++) next
      if (c == "[") print name "\t1"; else if (c == q) print name "\t0" }'
}

_lint_doctor_eslint() { # <recommended config>
  local rec="$1" f found="" r re tuned state rv cv
  for f in "${LINT_ESLINT_CONFIGS[@]}"; do [[ -f "$f" ]] && found="$found $f"; done
  if [[ -n "$found" ]]; then
    printf 'note\tESLint, rules looked up by name in%s; the linter was not asked, so a named rule may still be off\n' "$found"
  else
    printf 'note\tESLint, no config at the repository root\n'
  fi
  _lint_eslint_rules "$rec" | while IFS=$'\t' read -r r tuned; do
    rv=-; cv=-; state=missing
    # The pattern is built outside $( ): bash 3.2 misreads a quote in a
    # double-quoted string inside a command substitution.
    re="['\"]$r['\"]"
    f=$(_lint_names "$re" "${LINT_ESLINT_CONFIGS[@]}") && state=named
    if [[ "$tuned" == 1 ]]; then
      rv="see $rec: rules['$r']"
      [[ "$state" == named ]] && cv="see $f: rules['$r']"
    fi
    printf 'row\teslint\t%s\t%s\t%s\t%s\n' "$r" "$state" "$rv" "$cv"
  done
}
# ================== end linter table ==================