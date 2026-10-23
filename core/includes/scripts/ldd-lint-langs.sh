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
#   lint_reports_settings <linter>  exit 0 when the linter reports the setting
#                                   of each rule, so the doctor compares values;
#                                   exit 1 when it reports only which rules run
#   lint_doctor <id> <setup dir> <file>  compare the repository's linter with
#                                   the plugin's recommended config for the
#                                   language. <file> is a source file of the
#                                   language, for a linter that resolves its
#                                   settings per file. Prints tab-separated
#                                   records, never an empty field:
#                                     note TAB <text>
#                                     config TAB <linter> TAB <path>
#                                     row TAB <linter> TAB <rule> TAB <state> TAB <recommended> TAB <current> TAB <source>
#                                   A config record names the repository's own
#                                   config file the linter read; there is none
#                                   when the linter read no file. The caller
#                                   writes its path relative to the working
#                                   directory (root_relative of ldd-lint.sh).
#                                   The rules: the ones the recommended config
#                                   enables, as the linter resolves it, beyond
#                                   the linter's default set, and the default
#                                   rules it names that the repository does not
#                                   run. state: runs · missing · limit looser
#                                   or limit stricter (the repository's setting
#                                   lets more code pass, or less, than the
#                                   recommended one) · options differ (the two
#                                   settings differ in a way that is not one
#                                   limit) · named (the rule is
#                                   named outside comments in the repository's
#                                   config; the linter was not asked) · cannot
#                                   verify: <why>. recommended and current: the
#                                   setting as the linter reports it, or "see
#                                   <file>: <key>" when the linter cannot report
#                                   it and a reader must look there, or "-".
#                                   source: linter (the linter said whether the
#                                   rule runs) or presence check (the rule was
#                                   found by name). An output the doctor cannot
#                                   read is "cannot verify", never an empty list.
#                                   A "cannot verify" row of rule "-" says that
#                                   the doctor cannot check the linter at all;
#                                   a row of a named rule says that it cannot
#                                   check that rule only
#   lint_cannot_local <state>       exit 0 when a "cannot verify" state names a
#                                   cause on this machine only: the linter is
#                                   not installed, or not on PATH

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

lint_reports_settings() {
  case "$1" in
    golangci-lint) return 1 ;;
  esac
  return 0
}

# lint_doctor <id> <setup dir> <file> [config] — the doctor's lines for the
# language's linter. A config is the file to compare in place of the
# repository's own: the linter reads it for the settings, for its own config
# check and for the rules that run, and the lines name it.
lint_doctor() {
  local cfg="${4:-}" t
  if [[ -n "$cfg" && ! -f "$cfg" ]]; then
    _lint_doctor_cannot "$(lint_doctor_linter "$1")" "the agreed config $cfg does not exist"
    return 0
  fi
  # Under the caller's LINT_TMP when it sets one, so its exit trap removes it
  t=$(mktemp -d "${LINT_TMP:-${TMPDIR:-/tmp}}/ldd-doctor.XXXXXX")
  case "$1" in
    go)                    _lint_doctor_golangci "$2/golangci.yaml" "$t" "$cfg" ;;
    python)                _lint_doctor_ruff "$2/ruff.toml" "$3" "$t" "$cfg" ;;
    typescript|javascript) _lint_doctor_eslint "$2/eslint.config.ldd.mjs" "$3" "$t" "$cfg" ;;
  esac
  rm -rf "$t"
}

_lint_doctor_cannot() { # <linter> <why>
  printf 'row\t%s\t-\tcannot verify: %s\t-\t-\tlinter\n' "$1" "$2"
}

# lint_cannot_local <state> — exit 0 when a "cannot verify" state names a cause
# on this machine only: the linter is not installed, or not on PATH. The other
# causes (the linter rejects a config, the agreed config is gone) are the same
# in every clone.
lint_cannot_local() {
  case "$1" in
    "cannot verify: golangci-lint is not installed"*) return 0 ;;
    "cannot verify: ruff is not on PATH"*)            return 0 ;;
    "cannot verify: eslint is not installed"*)        return 0 ;;
  esac
  return 1
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
  tr -d '\n' < "$1" | sed 's/"Disabled":.*//' | grep -oE '"name":"[^"]+"' | sed 's/^"name":"//; s/"$//' | LC_ALL=C sort -u
}

# _lint_golangci_alternative <linter> — a linter the recommended config
# accepts in its place (its own comment says to enable one of the two)
_lint_golangci_alternative() {
  case "$1" in
    gocyclo) printf 'cyclop' ;;
  esac
  return 0
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

# _lint_golangci <chosen config> <arguments> — runs the linter, with -c <chosen
# config> when there is one
_lint_golangci() {
  local c="$1"; shift
  if [[ -n "$c" ]]; then golangci-lint "$@" -c "$c"; else golangci-lint "$@"; fi
}

# _lint_golangci_default — the config file the linter finds from this
# directory up, nothing when it finds none
_lint_golangci_default() {
  golangci-lint config path --json 2>/dev/null | sed -n 's/.*"path":"\([^"]*\)".*/\1/p'
}

# _lint_golangci_who — the binary on PATH and its version, as the doctor's
# note names them, so a reader can compare them with a version the project pins
_lint_golangci_who() {
  local v
  v=$(golangci-lint version --short 2>/dev/null | head -1)
  printf 'golangci-lint %s, version %s' "$(command -v golangci-lint)" "${v:-unknown}"
}

_lint_doctor_golangci() { # <recommended config> <work dir> [chosen config]
  local rec="$1" t="$2" chosen="${3:-}" out cfg dflt="" r re state tuned rv cv here alt held why who which="the repository config"
  command -v golangci-lint >/dev/null 2>&1 || { _lint_doctor_cannot golangci-lint "golangci-lint is not installed"; return 0; }
  who=$(_lint_golangci_who)
  golangci-lint linters --json -c "$rec" > "$t/rec.json" 2> "$t/err" \
    || { _lint_doctor_cannot golangci-lint "golangci-lint cannot run with the recommended config: $(_lint_first_error "$t/err")"; return 0; }
  golangci-lint linters --json --no-config > "$t/def.json" 2> "$t/err" \
    || { _lint_doctor_cannot golangci-lint "the linter fails with no config: $(_lint_first_error "$t/err")"; return 0; }
  if [[ -n "$chosen" ]]; then
    cfg="$chosen"; which="the chosen config"; dflt=$(_lint_golangci_default)
    [[ -z "$dflt" ]] || dflt=$(root_relative "$dflt")
  else
    # "path" is "" when the linter finds no config from this directory up
    out=$(golangci-lint config path --json 2>/dev/null) \
      || { _lint_doctor_cannot golangci-lint "the linter cannot say which config it reads"; return 0; }
    case "$out" in
      *'"path":'*) cfg=$(printf '%s' "$out" | sed -n 's/.*"path":"\([^"]*\)".*/\1/p')
                   [[ -z "$cfg" ]] || cfg=$(root_relative "$cfg") ;;
      *) _lint_doctor_cannot golangci-lint "cannot read the linter's answer to which config it reads"; return 0 ;;
    esac
  fi
  if [[ -n "$cfg" ]]; then
    # A schema failure is a rejection. Any other failure (no network for the
    # schema, for example) leaves the check unanswered: a note says so, with
    # the linter's message, and the doctor goes on.
    if ! _lint_golangci "$chosen" config verify > /dev/null 2> "$t/err"; then
      if grep -q '^jsonschema:' "$t/err"; then
        why=$(grep -m1 '^jsonschema:' "$t/err" | tr '\t' ' ')
        _lint_doctor_cannot golangci-lint "$which fails the linter's check: $why"
        return 0
      fi
      printf 'note\tgolangci-lint did not check the config: %s\n' "$(_lint_first_error "$t/err")"
    fi
    _lint_golangci "$chosen" linters --json > "$t/repo.json" 2> "$t/err" \
      || { _lint_doctor_cannot golangci-lint "the linter rejects $cfg: $(_lint_first_error "$t/err")"; return 0; }
    [[ -f "$cfg" ]] && printf 'config\tgolangci-lint\t%s\n' "$cfg"
    [[ -n "$dflt" && "$dflt" != "$cfg" && -f "$dflt" ]] && printf 'config\tgolangci-lint\t%s\n' "$dflt"
    printf 'note\t%s, %s %s; the linter reports which linters run, not their settings; revive rules are found by name, so enable-all-rules and a disabled rule are not seen\n' "$who" "$which" "$cfg"
    here="see $cfg"
  else
    cp "$t/def.json" "$t/repo.json"
    printf 'note\t%s, no repository config: the linter runs its default set\n' "$who"
    here="the linter's default"
  fi
  _lint_golangci_names "$t/rec.json" > "$t/rec"
  _lint_golangci_names "$t/def.json" > "$t/def"
  _lint_golangci_names "$t/repo.json" > "$t/repo"
  [[ -s "$t/rec" && -s "$t/def" ]] \
    || { _lint_doctor_cannot golangci-lint "cannot read the linter's list of the linters it runs"; return 0; }
  _lint_doctor_sets "$t/rec" "$t/def" "$t/repo" "$rec" | while IFS=$'\t' read -r r state; do
    rv=-; cv=-; alt=$(_lint_golangci_alternative "$r"); held="$r"
    if [[ "$state" == missing && -n "$alt" ]] && grep -qxF -- "$alt" "$t/repo"; then
      state=runs; held="$alt"
    fi
    if _lint_golangci_tuned "$rec" "$r"; then
      rv="see $rec: linters.settings.$r"
      [[ "$state" == runs && -n "$cfg" ]] && cv="see $cfg: linters.settings.$held, the linter's default when absent"
      [[ "$state" == runs && -z "$cfg" ]] && cv="the linter's default"
    fi
    [[ "$held" != "$r" ]] && cv="$held runs in its place; $cv"
    printf 'row\tgolangci-lint\t%s\t%s\t%s\t%s\tlinter\n' "$r" "$state" "$rv" "$cv"
  done
  grep -qxF revive "$t/rec" || return 0
  # The linter cannot say which revive rules run: a rule the repository's
  # config names outside comments is "named". The name field reads alike in
  # YAML (name: r), TOML (name = "r") and JSON ("name": "r").
  _lint_revive_rules "$rec" | while IFS=$'\t' read -r r tuned; do
    rv=-; cv=-; state=missing
    re="(^|[^A-Za-z0-9_-])[\"']?name[\"']?[[:space:]]*[:=][[:space:]]*[\"']?$r[\"']?([[:space:],}]|$)"
    grep -qxF revive "$t/repo" && [[ -n "$cfg" ]] && _lint_names "$re" "$cfg" >/dev/null && state=named
    if [[ "$tuned" == 1 ]]; then
      rv="see $rec: linters.settings.revive.rules, name $r"
      [[ "$state" == named ]] && cv="$here: linters.settings.revive.rules, name $r"
    fi
    printf 'row\tgolangci-lint\trevive %s\t%s\t%s\t%s\tpresence check\n' "$r" "$state" "$rv" "$cv"
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

# _lint_ruff_setting <code> — the setting that holds the rule's limit. Each is
# a maximum: a larger value lets more code pass.
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

# _lint_limit_state <recommended> <current> — of a maximum: "runs" when the
# two are equal, "limit looser" when the current one is larger, "limit
# stricter" when it is smaller; "options differ" when one is not a whole number
_lint_limit_state() {
  if [[ "$1" == "$2" ]]; then printf 'runs'
  elif [[ ! "$1" =~ ^[0-9]+$ || ! "$2" =~ ^[0-9]+$ ]]; then printf 'options differ'
  elif (( $2 > $1 )); then printf 'limit looser'
  else printf 'limit stricter'; fi
}

# _lint_ruff_show <bin> <chosen config> <file> — the settings ruff resolves for
# the file, with --config <chosen config> when there is one
_lint_ruff_show() {
  if [[ -n "$2" ]]; then "$1" check --no-cache --color never --show-settings --config "$2" "$3"
  else "$1" check --no-cache --color never --show-settings "$3"; fi
}

# _lint_ruff_path <show-settings output> — its settings path, relative to the
# working directory (root_relative of ldd-lint.sh); nothing when ruff names none
_lint_ruff_path() {
  local p
  p=$(sed -n 's/^Settings path: "\(.*\)"$/\1/p' "$1")
  [[ -z "$p" ]] || root_relative "$p"
}

_lint_doctor_ruff() { # <recommended config> <file> <work dir> [chosen config]
  local rec="$1" f="./$2" t="$3" chosen="${4:-}" bin sp dflt="" from which="the repository's config" r state key rv cv a b
  bin=$(command -v ruff) || { _lint_doctor_cannot ruff "ruff is not on PATH; put the project's ruff on PATH (for example, activate the project's virtual environment) and run again"; return 0; }
  [[ -n "$2" ]] || { _lint_doctor_cannot ruff "no source file to resolve the settings for"; return 0; }
  "$bin" check --no-cache --color never --show-settings --config "$rec" "$f" > "$t/rec.txt" 2> "$t/err" \
    || { _lint_doctor_cannot ruff "ruff cannot run with the recommended config: $(_lint_first_error "$t/err")"; return 0; }
  "$bin" check --no-cache --color never --show-settings --isolated "$f" > "$t/def.txt" 2> "$t/err" \
    || { _lint_doctor_cannot ruff "the linter fails with no config: $(_lint_first_error "$t/err")"; return 0; }
  [[ -n "$chosen" ]] && which="the chosen config $chosen"
  _lint_ruff_show "$bin" "$chosen" "$f" > "$t/repo.txt" 2> "$t/err" \
    || { _lint_doctor_cannot ruff "the linter rejects $which: $(_lint_first_error "$t/err")"; return 0; }
  if [[ -n "$chosen" ]]; then
    sp="$chosen"; from="the chosen config $chosen"
    _lint_ruff_show "$bin" "" "$f" > "$t/dflt.txt" 2>/dev/null && dflt=$(_lint_ruff_path "$t/dflt.txt")
  else
    sp=$(_lint_ruff_path "$t/repo.txt")
    [[ -n "$sp" ]] || sp="no config file, the linter's defaults"
    from="$sp"
  fi
  [[ -f "$sp" ]] && printf 'config\truff\t%s\n' "$sp"
  [[ -n "$dflt" && "$dflt" != "$sp" && -f "$dflt" ]] && printf 'config\truff\t%s\n' "$dflt"
  printf 'note\truff %s, the settings resolved for %s from %s\n' "$bin" "$2" "$from"
  _lint_ruff_rules "$t/rec.txt" > "$t/rec"
  _lint_ruff_rules "$t/def.txt" > "$t/def"
  _lint_ruff_rules "$t/repo.txt" > "$t/repo"
  [[ -s "$t/rec" && -s "$t/def" ]] \
    || { _lint_doctor_cannot ruff "cannot read the linter's list of the rules it runs"; return 0; }
  _lint_doctor_sets "$t/rec" "$t/def" "$t/repo" "$rec" | while IFS=$'\t' read -r r state; do
    rv=-; cv=-
    key=$(_lint_ruff_setting "$r")
    if [[ -n "$key" ]]; then
      a=$(_lint_ruff_value "$t/rec.txt" "$key"); b=$(_lint_ruff_value "$t/repo.txt" "$key")
      rv="$key = $a"
      if [[ -z "$a" || ( "$state" == runs && -z "$b" ) ]]; then
        state="cannot verify: the linter reports no $key"; rv=-
      elif [[ "$state" == runs ]]; then
        cv="$key = $b"
        state=$(_lint_limit_state "$a" "$b")
      fi
    fi
    printf 'row\truff\t%s\t%s\t%s\t%s\tlinter\n' "$r" "$state" "$rv" "$cv"
  done
}

# ESLint: the doctor runs the project's own ESLint (node_modules/.bin/eslint)
# with --print-config on one source file: the config as ESLint resolves it,
# shared configs included.

# _lint_eslint_rules <config> — "rule TAB options" for every rule the
# recommended config sets, once per rule, in the order the config first sets
# it: options is the text after the severity when it fits on the rule's line,
# "..." when it runs on, "-" when there is none; a rule set to "off" (as for
# test files) is left out
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
      if (c == q) { print name "\t-"; next }
      if (c != "[") next
      opts = after; sub(/[ \t]*,?[ \t]*$/, "", opts)
      if (opts !~ /\]$/) { print name "\t..."; next }
      sub(/\]$/, "", opts); sub(/^\[[^,]*/, "", opts)
      if (opts == "") { print name "\t-"; next }
      sub(/^,[ \t]*/, "", opts); print name "\t" opts }'
}

# _lint_eslint_resolved <file> — "rule TAB severity TAB options" for every rule
# of an "eslint --print-config" output (JSON, two spaces per level); options
# is the rest of the rule's array on one line, "-" when there is none. A first
# line "#rules" says the output has a rules object, which may be empty
_lint_eslint_resolved() {
  awk '
    function flush() {
      if (key == "") return
      sub(/,$/, "", val); sub(/^\[/, "", val); sub(/\]$/, "", val)
      sev = val; sub(/,.*$/, "", sev); gsub(/"/, "", sev)
      opts = "-"; if (index(val, ",") > 0) opts = substr(val, index(val, ",") + 1)
      print key "\t" sev "\t" opts; key = ""
    }
    /^  "rules": [{][}]/ { print "#rules"; exit }
    /^  "rules": [{]/ { print "#rules"; r = 1; next }
    !r { next }
    /^  [}]/ { flush(); exit }
    /^    "/ { flush(); key = $0; sub(/^    "/, "", key); sub(/".*$/, "", key)
               val = $0; sub(/^    "[^"]*":[ ]*/, "", val); next }
    { v = $0; sub(/^ +/, "", v); val = val v }
    END { flush() }' "$1"
}

# _lint_eslint_error <file> — the line of ESLint's stderr that says what went
# wrong, past its "Oops!" banner and version line
_lint_eslint_error() {
  grep -vE '^(Oops!|ESLint: [0-9]|[[:space:]]*$)' "$1" > "$1.lines"
  { grep -m1 -i 'error' "$1.lines" || head -1 "$1.lines"; } | tr '\t' ' '
}

# _lint_eslint_compare <recommended options> <current options> — the state of
# a rule that runs: runs when the options agree, or when either side sets
# none; limit looser or limit stricter when the recommended options are one
# limit (a number, or one key with a number) and the current one holds that
# limit at another value; options differ otherwise. Each limit is a maximum.
_lint_eslint_compare() {
  local rn cn re_num='^[0-9]+$' re_key='^[{]([A-Za-z]+):([0-9]+)[}]$' k n m
  case "$1" in -|...) printf 'runs'; return 0 ;; esac
  [[ "$2" == - ]] && { printf 'runs'; return 0; }
  rn=$(printf '%s' "$1" | tr -d "\"' \t"); cn=$(printf '%s' "$2" | tr -d "\"' \t")
  [[ "$rn" == "$cn" ]] && { printf 'runs'; return 0; }
  if [[ "$rn" =~ $re_num ]]; then
    if [[ "$cn" =~ $re_num ]]; then _lint_limit_state "$rn" "$cn"; else printf 'options differ'; fi
    return 0
  fi
  if [[ "$rn" =~ $re_key ]]; then
    k="${BASH_REMATCH[1]}"; n="${BASH_REMATCH[2]}"
    m=$(printf '%s\n' "$cn" | sed -n "s/.*[{,]$k:\([0-9][0-9]*\)[,}].*/\1/p")
    if [[ -n "$m" && "$m" != "$n" ]]; then _lint_limit_state "$n" "$m"; return 0; fi
  fi
  printf 'options differ'
}

# _lint_eslint_bin — the project's ESLint: node_modules/.bin/eslint in this
# directory, or in a directory above it up to the top of the git work tree,
# where a workspace keeps its hoisted packages
_lint_eslint_bin() {
  local d top
  d=$(pwd -P); top=$(git rev-parse --show-toplevel 2>/dev/null) || top="$d"
  top=$(cd "$top" && pwd -P)
  while :; do
    [[ -x "$d/node_modules/.bin/eslint" ]] && { printf '%s' "$d/node_modules/.bin/eslint"; return 0; }
    [[ "$d" == "$top" || "$d" == / ]] && return 1
    d=$(dirname "$d")
  done
}

# _lint_eslint_pnp — exit 0 when a Yarn Plug'n'Play install serves this
# directory: then no node_modules/.bin holds ESLint
_lint_eslint_pnp() {
  local d top
  d=$(pwd -P); top=$(git rev-parse --show-toplevel 2>/dev/null) || top="$d"
  top=$(cd "$top" && pwd -P)
  while :; do
    [[ -f "$d/.pnp.cjs" ]] && return 0
    [[ "$d" == "$top" || "$d" == / ]] && return 1
    d=$(dirname "$d")
  done
}

# _lint_eslint_config_file — the repository's own ESLint config in the working
# directory: a flat config, else a legacy .eslintrc file, else package.json
# when it has an eslintConfig key; exit 1 when there is none
_lint_eslint_config_file() {
  local f
  for f in "${LINT_ESLINT_CONFIGS[@]}"; do
    [[ "$f" == eslint.config.ldd.mjs ]] && continue
    [[ -f "$f" ]] && { printf '%s' "$f"; return 0; }
  done
  [[ -f package.json ]] && grep -q '"eslintConfig"[[:space:]]*:' package.json && { printf 'package.json'; return 0; }
  return 1
}

# _lint_eslint_print <bin> <chosen config> <file> — the config ESLint resolves
# for the file, with -c <chosen config> when there is one
_lint_eslint_print() {
  if [[ -n "$2" ]]; then "$1" -c "$2" --print-config "$3"; else "$1" --print-config "$3"; fi
}

_lint_doctor_eslint() { # <recommended config> <file> <work dir> [chosen config]
  local rec="$1" t="$3" chosen="${4:-}" bin r ro sev opts state rv cv a b cfg dflt which="the repository's config"
  if ! bin=$(_lint_eslint_bin); then
    if _lint_eslint_pnp; then
      _lint_doctor_cannot eslint "eslint is not installed in node_modules: the project uses Yarn Plug'n'Play"
    else
      local sub
      sub=$(find . -maxdepth 4 -path '*/node_modules/.bin/eslint' -not -path '*/node_modules/*/node_modules/*' 2>/dev/null \
            | sed 's|^\./||; s|/node_modules/\.bin/eslint$||' | LC_ALL=C sort | head -3 | tr '\n' ' ')
      if [[ -n "$sub" ]]; then
        _lint_doctor_cannot eslint "eslint is not installed here, but in a project below: ${sub% }; run the doctor with --root on that project"
      else
        _lint_doctor_cannot eslint "eslint is not installed in this project (no node_modules/.bin/eslint): install its packages"
      fi
    fi
    return 0
  fi
  _lint_eslint_rules "$rec" > "$t/rec"
  [[ -s "$t/rec" ]] || { _lint_doctor_cannot eslint "cannot read the rules of the recommended config $rec"; return 0; }
  [[ -n "$2" ]] || { _lint_doctor_cannot eslint "no source file to resolve the config for"; return 0; }
  [[ -n "$chosen" ]] && which="the chosen config $chosen"
  _lint_eslint_print "$bin" "$chosen" "./$2" > "$t/repo.json" 2> "$t/err" \
    || { _lint_doctor_cannot eslint "the linter rejects $which: $(_lint_eslint_error "$t/err")"; return 0; }
  if [[ "$(tr -d '[:space:]' < "$t/repo.json")" == undefined ]]; then
    _lint_doctor_cannot eslint "ESLint ignores $2; run the doctor with --root on a directory whose files ESLint checks"
    return 0
  fi
  _lint_eslint_resolved "$t/repo.json" > "$t/resolved"
  grep -qx '#rules' "$t/resolved" || { _lint_doctor_cannot eslint "cannot read the linter's resolved config for $2"; return 0; }
  if [[ -n "$chosen" ]]; then
    printf 'config\teslint\t%s\n' "$chosen"
    dflt=$(_lint_eslint_config_file) && [[ "$dflt" != "$chosen" ]] && printf 'config\teslint\t%s\n' "$dflt"
    printf 'note\tESLint %s, the config resolved for %s from the chosen config %s\n' "$bin" "$2" "$chosen"
  else
    cfg=$(_lint_eslint_config_file) && printf 'config\teslint\t%s\n' "$cfg"
    printf 'note\tESLint %s, the config resolved for %s\n' "$bin" "$2"
  fi
  while IFS=$'\t' read -r r ro; do
    rv=-; cv=-; state=missing
    case "$ro" in
      -)    ;;
      ...)  rv="see $rec: rules['$r']" ;;
      *)    rv="$ro" ;;
    esac
    IFS=$'\t' read -r sev opts < <(awk -F'\t' -v r="$r" '$1 == r { print $2 "\t" $3; exit }' "$t/resolved")
    case "${sev:-0}" in
      0|off) ;;
      *)
        state=runs; cv="$opts"
        [[ "$sev" == 1 || "$sev" == warn ]] && cv="warn; $opts"
        state=$(_lint_eslint_compare "$ro" "$opts") ;;
    esac
    sev=""; opts=""
    printf 'row\teslint\t%s\t%s\t%s\t%s\tlinter\n' "$r" "$state" "$rv" "$cv"
  done < "$t/rec"
}
# ================== end linter table ==================