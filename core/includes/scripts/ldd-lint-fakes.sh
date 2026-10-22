# ==================== fake linters for the doctor ====================
# What the doctor cases need per language id: a fake of the language's
# linter, which prints the output the real one prints, and the repository
# config the case writes. The fakes let the matrix run where no linter is
# installed; the "installed linter" case checks the parsers against the real
# output where one is.
# residue-exempt: the fakes name every language's linter and config file on
# purpose, the same in every rendering.
#
#   fake_doctor_row          set the row's FAKE_* variables (below)
#   fake_doctor <mode>       write $REPO/.bin (the fake linter, when the
#                            language has one) and the repository config.
#                            Modes: adopt (the repository runs every
#                            recommended rule at the recommended settings),
#                            missing (it leaves FAKE_RULE out), relaxed (it sets
#                            another limit for FAKE_RULE), commented (it names
#                            FAKE_NAMED_RULE only inside a comment), reject
#                            (the linter rejects the repository's config),
#                            garbled (the linter prints an output of another
#                            shape)
#   real_doctor_adopt        copy the plugin's recommended config into $REPO as
#                            the repository's own config
#
#   FAKE_LINTER      the linter the doctor names in its rows
#   FAKE_BIN         the linter's executable; "" when the doctor runs none
#   FAKE_RULE        a recommended rule with a setting
#   FAKE_RUNS        the state of a rule the adopted config holds
#   FAKE_RELAXED     the text of FAKE_RULE's row in the relaxed mode
#   FAKE_NAMED_RULE  a rule the doctor finds by name in the repository's
#                    config; "" when the linter reports every rule itself
#   FAKE_CONFIG      the repository config the fake modes write

fake_doctor_row() {
  case "$ROW" in
    go)
      FAKE_LINTER='golangci-lint'; FAKE_BIN='golangci-lint'; FAKE_RULE='funlen'; FAKE_RUNS='runs'
      FAKE_RELAXED="funlen: runs; recommended: see $(_fake_setup golangci.yaml): linters.settings.funlen; current: see .golangci.yaml: linters.settings.funlen, the linter's default when absent"
      FAKE_NAMED_RULE='revive file-length-limit'; FAKE_CONFIG='.golangci.yaml' ;;
    python)
      FAKE_LINTER='ruff'; FAKE_BIN='ruff'; FAKE_RULE='PLR0913'; FAKE_RUNS='runs'
      FAKE_RELAXED='PLR0913: limit differs; recommended: pylint.max_args = 4; current: pylint.max_args = 7'
      FAKE_NAMED_RULE=''; FAKE_CONFIG='pyproject.toml' ;;
    typescript)
      FAKE_LINTER='eslint'; FAKE_BIN=''; FAKE_RULE='max-params'; FAKE_RUNS='named'
      FAKE_RELAXED="max-params: named; recommended: see $(_fake_setup eslint.config.ldd.mjs): rules['max-params']; current: see eslint.config.mjs: rules['max-params']"
      FAKE_NAMED_RULE='max-params'; FAKE_CONFIG='eslint.config.mjs' ;;
  esac
}

# _fake_setup <file> — the plugin's recommended config of that name
_fake_setup() { printf '%s/%s' "$(cd "$(dirname "$LINT")/../setup" && pwd)" "$1"; }

# _fake_golangci_json <name>... — a "linters --json" output enabling those
_fake_golangci_json() {
  local n sep=""
  printf '{"Enabled":['
  for n in "$@"; do printf '%s{"name":"%s","description":"Checks \\"name\\":\\"x\\" text.","fast":true}' "$sep" "$n"; sep=","; done
  printf '],"Disabled":[{"name":"dupl","description":"Detects duplicate fragments of code."}]}\n'
}

# _fake_ruff_settings <settings path or ""> <max_args> <code>... — a
# "--show-settings" output enabling those codes
_fake_ruff_settings() {
  local sp="$1" args="$2" root c; shift 2
  root=$(cd "$REPO" && pwd -P)
  printf 'Resolved settings for: "%s/src/a.py"\n' "$root"
  [[ -n "$sp" ]] && printf 'Settings path: "%s/%s"\n' "$root" "$sp"
  printf '\n# Linter Settings\nlinter.exclude = []\nlinter.rules.enabled = [\n'
  for c in "$@"; do printf '\tsome-rule (%s),\n' "$c"; done
  printf ']\nlinter.rules.should_fix = [\n\tsome-rule (B006),\n]\n'
  printf 'linter.mccabe.max_complexity = 8\nlinter.pylint.max_args = %s\nlinter.pylint.max_nested_blocks = 2\n' "$args"
}

_fake_bin() { # <name> <script body>
  mkdir -p "$REPO/.bin"
  printf '#!/bin/sh\nd=$(dirname "$0")\n%s\n' "$2" > "$REPO/.bin/$1"
  chmod +x "$REPO/.bin/$1"
}

fake_doctor() { # <mode>
  local mode="$1" b="$REPO/.bin"
  case "$ROW" in
    go)
      _fake_bin golangci-lint '
if [ "$1" = config ]; then cat "$d/path.json"; exit 0; fi
[ "$1" = linters ] || exit 9
for a in "$@"; do
  case "$a" in
    --no-config) cat "$d/default.json"; exit 0 ;;
    */setup/golangci.yaml) cat "$d/recommended.json"; exit 0 ;;
  esac
done
if [ -f "$d/reject.txt" ]; then cat "$d/reject.txt" >&2; exit 3; fi
cat "$d/repo.json"'
      printf '{"absolutePath":"/r/.golangci.yaml","path":".golangci.yaml"}\n' > "$b/path.json"
      _fake_golangci_json errcheck govet > "$b/default.json"
      _fake_golangci_json errcheck funlen gochecknoglobals govet nestif revive > "$b/recommended.json"
      cp "$b/recommended.json" "$b/repo.json"
      cp "$(_fake_setup golangci.yaml)" "$REPO/.golangci.yaml"
      case "$mode" in
        missing)   _fake_golangci_json errcheck gochecknoglobals govet nestif revive > "$b/repo.json" ;;
        relaxed)   sed 's/lines: 50/lines: 80/' "$(_fake_setup golangci.yaml)" > "$REPO/.golangci.yaml" ;;
        commented) sed 's/- name: file-length-limit/# - name: file-length-limit/' "$(_fake_setup golangci.yaml)" > "$REPO/.golangci.yaml" ;;
        reject)    printf 'Error: can'"'"'t load config: unsupported version of the configuration: ""\n' > "$b/reject.txt" ;;
        garbled)   for f in path default recommended repo; do printf 'Enabled by your configuration linters:\nfunlen: Checks for long functions.\n' > "$b/$f.json"; done ;;
      esac ;;
    python)
      _fake_bin ruff '
for a in "$@"; do
  case "$a" in
    --isolated) cat "$d/default.txt"; exit 0 ;;
    */setup/ruff.toml) cat "$d/recommended.txt"; exit 0 ;;
  esac
done
if [ -f "$d/reject.txt" ]; then cat "$d/reject.txt" >&2; exit 2; fi
cat "$d/repo.txt"'
      _fake_ruff_settings '' 5 E401 F401 > "$b/default.txt"
      _fake_ruff_settings ruff.toml 4 B006 C901 E401 F401 PLR0913 PLR1702 > "$b/recommended.txt"
      _fake_ruff_settings pyproject.toml 4 B006 C901 E401 F401 PLR0913 PLR1702 > "$b/repo.txt"
      printf '[tool.ruff.lint]\nextend-select = ["B006", "C901", "PLR0913", "PLR1702"]\n' > "$REPO/pyproject.toml"
      case "$mode" in
        missing) _fake_ruff_settings pyproject.toml 4 B006 C901 E401 F401 PLR1702 > "$b/repo.txt" ;;
        relaxed) _fake_ruff_settings pyproject.toml 7 B006 C901 E401 F401 PLR0913 PLR1702 > "$b/repo.txt" ;;
        reject)  printf 'ruff failed\n  Cause: Failed to parse pyproject.toml\n' > "$b/reject.txt" ;;
        garbled) for f in default recommended repo; do printf 'linter.rules.enabled = 3 rules\n' > "$b/$f.txt"; done ;;
      esac ;;
    typescript)
      cp "$(_fake_setup eslint.config.ldd.mjs)" "$REPO/eslint.config.mjs"
      case "$mode" in
        missing)   sed "/'max-params'/d" "$(_fake_setup eslint.config.ldd.mjs)" > "$REPO/eslint.config.mjs" ;;
        relaxed)   sed "s/'max-params': \['error', 4\]/'max-params': ['error', 6]/" "$(_fake_setup eslint.config.ldd.mjs)" > "$REPO/eslint.config.mjs" ;;
        commented) sed "s|^\( *\)'max-params'|\1// 'max-params'|" "$(_fake_setup eslint.config.ldd.mjs)" > "$REPO/eslint.config.mjs" ;;
      esac ;;
  esac
}

real_doctor_adopt() {
  case "$ROW" in
    go)         cp "$(_fake_setup golangci.yaml)" "$REPO/.golangci.yaml" ;;
    python)     cp "$(_fake_setup ruff.toml)" "$REPO/ruff.toml" ;;
    typescript) cp "$(_fake_setup eslint.config.ldd.mjs)" "$REPO/eslint.config.mjs" ;;
  esac
}
# ================== end fake linters for the doctor ==================
