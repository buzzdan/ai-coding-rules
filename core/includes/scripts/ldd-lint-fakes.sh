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
#   fake_doctor <mode>       write the fake linter ($REPO/.bin, or the
#                            project's node_modules/.bin) and the repository
#                            config.
#                            Modes: adopt (the repository runs every
#                            recommended rule at the recommended settings),
#                            missing (it leaves FAKE_RULE out), relaxed (it sets
#                            a looser limit for FAKE_RULE), tightened (a
#                            stricter one), alternative (it runs, in place
#                            of a recommended linter, the one the recommended
#                            config accepts instead), commented (it names
#                            FAKE_NAMED_RULE only inside a comment), reject
#                            (the linter rejects the repository's config),
#                            garbled (the linter prints an output of another
#                            shape), ignored (the linter skips the file the
#                            doctor resolves the config for), optsdiffer
#                            (a rule set with other options), norules (the
#                            config loads and sets no rule), toml and json (the
#                            repository's config is in that format and names
#                            FAKE_NAMED_RULE), invalid (the linter's own
#                            config check fails on a schema error) and
#                            noschema (that check cannot fetch the schema)
#   fake_doctor_strict <path>  write a second config file at $REPO/<path>, which
#                            the linter reports on as on the recommended
#                            config; the golangci-lint fake logs its calls in
#                            $REPO/.bin/calls.log
#   real_doctor_adopt        copy the plugin's recommended config into $REPO as
#                            the repository's own config
#
#   FAKE_LINTER      the linter the doctor names in its rows
#   FAKE_BIN         the linter's executable
#   FAKE_REAL        the executable on PATH the installed-linter case needs;
#                    "" when the linter is installed per project
#   FAKE_RULE        a recommended rule with a setting
#   FAKE_RUNS        the state of a rule the adopted config holds
#   FAKE_RELAXED     the text of FAKE_RULE's row in the relaxed mode, and
#   FAKE_TIGHTENED   in the tightened mode; "" when the linter reports no
#                    setting, so the doctor cannot compare one
#   FAKE_ALTERNATIVE the text of the row in the alternative mode; "" when
#                    the recommended config names no alternative
#   FAKE_NAMED_RULE  a rule the doctor finds by name in the repository's
#                    config; "" when the linter reports every rule itself
#   FAKE_CONFIG      the repository config the fake modes write
#   FAKE_WARN        the text of a row whose rule the adopted config runs as a
#                    warning; "" when the linter reports no severity
#   FAKE_IGNORED     the text the doctor prints in the ignored mode; "" when
#                    the linter resolves its settings for any file
#   FAKE_NORULES     1 when the linter can report a config with no rule, is
#                    installed per project, and resolves its config per file
#   FAKE_OPTIONS     the text of a row in the optsdiffer mode (a rule set with
#                    options that are not one limit); "" when the linter
#                    reports no such options
#   FAKE_FORMATS     the other config formats the toml and json modes write;
#                    "" when the language has one
#   FAKE_NO_SETTINGS "yes" when the linter reports only which rules run, never
#                    a setting, so an agreed rule is matched by name; "" if not
#   FAKE_BARE_RULE   a rule that runs in the adopted config and has no setting
#                    in its row (recommended and current are "-"); "" when no
#                    such rule exists
#   FAKE_SEE_RULE    a rule whose recommended side is a place to read, though
#                    the linter reports the current setting; "" if none
#   FAKE_LEGACY_CONFIG an older config file name the doctor also compares (the
#                    fixture writes it in place of FAKE_CONFIG); "" if none
#   FAKE_CONFIG_CHECK "yes" when the linter has a config check of its own,
#                    which the invalid and noschema modes fail; "" if not

fake_doctor_row() {
  case "$ROW" in
    go)
      FAKE_LINTER='golangci-lint'; FAKE_BIN='golangci-lint'; FAKE_REAL='golangci-lint'; FAKE_RULE='funlen'; FAKE_RUNS='runs'; FAKE_TIGHTENED=''
      FAKE_WARN=''; FAKE_IGNORED=''; FAKE_NORULES=''; FAKE_OPTIONS=''; FAKE_FORMATS='toml json'; FAKE_CONFIG_CHECK='yes'
      FAKE_NO_SETTINGS='yes'; FAKE_BARE_RULE='gochecknoglobals'; FAKE_SEE_RULE=''; FAKE_LEGACY_CONFIG=''
      FAKE_ALTERNATIVE="gocyclo: runs; recommended: see $(_fake_setup golangci.yaml): linters.settings.gocyclo; current: cyclop runs in its place; see .golangci.yaml: linters.settings.cyclop"
      FAKE_RELAXED="funlen: runs; recommended: see $(_fake_setup golangci.yaml): linters.settings.funlen; current: see .golangci.yaml: linters.settings.funlen, the linter's default when absent"
      FAKE_NAMED_RULE='revive file-length-limit'; FAKE_CONFIG='.golangci.yaml' ;;
    python)
      FAKE_LINTER='ruff'; FAKE_BIN='ruff'; FAKE_REAL='ruff'; FAKE_RULE='PLR0913'; FAKE_RUNS='runs'; FAKE_ALTERNATIVE=''
      FAKE_WARN=''; FAKE_IGNORED=''; FAKE_NORULES=''; FAKE_OPTIONS=''; FAKE_FORMATS=''; FAKE_CONFIG_CHECK=''
      FAKE_NO_SETTINGS=''; FAKE_BARE_RULE=''; FAKE_SEE_RULE=''; FAKE_LEGACY_CONFIG=''
      FAKE_RELAXED='PLR0913: limit looser; recommended: pylint.max_args = 4; current: pylint.max_args = 7'
      FAKE_TIGHTENED='PLR0913: limit stricter; recommended: pylint.max_args = 4; current: pylint.max_args = 3'
      FAKE_NAMED_RULE=''; FAKE_CONFIG='pyproject.toml' ;;
    typescript)
      FAKE_LINTER='eslint'; FAKE_BIN='eslint'; FAKE_REAL=''; FAKE_RULE='max-params'; FAKE_RUNS='runs'; FAKE_ALTERNATIVE=''
      FAKE_RELAXED='max-params: limit looser; recommended: 4; current: 6'
      FAKE_TIGHTENED='max-params: limit stricter; recommended: 4; current: 3'
      FAKE_OPTIONS='no-param-reassign: options differ; recommended: { props: true }; current: {"props": false}'
      FAKE_WARN='sonarjs/elseif-without-else: runs; recommended: -; current: warn; -'
      FAKE_IGNORED='cannot verify: ESLint ignores src/a'
      FAKE_NORULES=1; FAKE_FORMATS=''; FAKE_CONFIG_CHECK=''
      FAKE_NO_SETTINGS=''; FAKE_BARE_RULE=''; FAKE_SEE_RULE='no-magic-numbers'; FAKE_LEGACY_CONFIG='.eslintrc.json'
      FAKE_NAMED_RULE=''; FAKE_CONFIG='eslint.config.mjs' ;;
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

_fake_bin() { # <name> <script body> [<dir>]
  local dir="${3:-$REPO/.bin}"
  mkdir -p "$dir"
  printf '#!/bin/sh\nd=$(dirname "$0")\n%s\n' "$2" > "$dir/$1"
  chmod +x "$dir/$1"
}

# _fake_eslint_json <mode> — an "eslint --print-config" output, laid out as
# ESLint lays it out, with every rule the recommended config sets at its
# recommended options: a number on its own line, a one-key limit as an object
# over several lines, other options left out
_fake_eslint_json() {
  local mode="$1" r ro rn n k sev re_num='^[0-9]+$' re_key='^[{]([A-Za-z]+):([0-9]+)[}]$'
  printf '{\n  "settings": {\n    "react": {\n      "version": "detect"\n    }\n  },\n  "rules": {\n'
  printf '    "constructor-super": [\n      0\n    ]'
  _lint_eslint_rules "$(_fake_setup eslint.config.ldd.mjs)" | while IFS=$'\t' read -r r ro; do
    rn=$(printf '%s' "$ro" | tr -d "\"' \t"); n=""; k=""; sev=2
    if [[ "$rn" =~ $re_num ]]; then n="$rn"
    elif [[ "$rn" =~ $re_key ]]; then k="${BASH_REMATCH[1]}"; n="${BASH_REMATCH[2]}"; fi
    [[ "$r" == sonarjs/elseif-without-else ]] && sev=1
    if [[ "$r" == max-params ]]; then
      case "$mode" in
        missing)   sev=0 ;;
        relaxed)   n=6 ;;
        tightened) n=3 ;;
      esac
    fi
    printf ',\n'
    if [[ "$r" == no-param-reassign && "$mode" == optsdiffer ]]; then
      printf '    "%s": [\n      2,\n      {\n        "props": false\n      }\n    ]' "$r"
    elif [[ -n "$k" && "$sev" != 0 ]]; then
      printf '    "%s": [\n      %s,\n      {\n        "%s": %s\n      }\n    ]' "$r" "$sev" "$k" "$n"
    elif [[ -n "$n" && "$sev" != 0 ]]; then
      printf '    "%s": [\n      %s,\n      %s\n    ]' "$r" "$sev" "$n"
    else
      printf '    "%s": [\n      %s\n    ]' "$r" "$sev"
    fi
  done
  printf '\n  },\n  "plugins": [\n    "react"\n  ]\n}\n'
}

fake_doctor() { # <mode>
  local mode="$1" b="$REPO/.bin"
  case "$ROW" in
    go)
      _fake_bin golangci-lint '
echo "$*" >> "$d/calls.log"
cfg=""; prev=""
for a in "$@"; do [ "$prev" = -c ] && cfg=$a; prev=$a; done
if [ "$1" = config ] && [ "$2" = verify ]; then
  if [ -f "$d/verify.txt" ] && [ -z "$cfg" ]; then cat "$d/verify.txt" >&2; exit 3; fi
  exit 0
fi
if [ "$1" = config ]; then cat "$d/path.json"; exit 0; fi
[ "$1" = linters ] || exit 9
for a in "$@"; do
  case "$a" in
    --no-config) cat "$d/default.json"; exit 0 ;;
    */setup/golangci.yaml) cat "$d/recommended.json"; exit 0 ;;
  esac
done
if [ -n "$cfg" ]; then
  [ -f "$cfg" ] || { echo "Error: no such config file: $cfg" >&2; exit 3; }
  if [ -f "$d/$(basename "$cfg").out" ]; then cat "$d/$(basename "$cfg").out"; exit 0; fi
fi
if [ -f "$d/reject.txt" ]; then cat "$d/reject.txt" >&2; exit 3; fi
cat "$d/repo.json"'
      printf '{"absolutePath":"/r/.golangci.yaml","path":".golangci.yaml"}\n' > "$b/path.json"
      _fake_golangci_json errcheck govet > "$b/default.json"
      _fake_golangci_json errcheck funlen gochecknoglobals gocyclo govet nestif revive > "$b/recommended.json"
      cp "$b/recommended.json" "$b/repo.json"
      cp "$(_fake_setup golangci.yaml)" "$REPO/.golangci.yaml"
      case "$mode" in
        missing)   _fake_golangci_json errcheck gochecknoglobals gocyclo govet nestif revive > "$b/repo.json" ;;
        alternative) _fake_golangci_json cyclop errcheck funlen gochecknoglobals govet nestif revive > "$b/repo.json" ;;
        relaxed)   sed 's/lines: 50/lines: 80/' "$(_fake_setup golangci.yaml)" > "$REPO/.golangci.yaml" ;;
        commented) sed 's/- name: file-length-limit/# - name: file-length-limit/' "$(_fake_setup golangci.yaml)" > "$REPO/.golangci.yaml" ;;
        toml)      rm -f "$REPO/.golangci.yaml"
                   printf '{"absolutePath":"/r/.golangci.toml","path":".golangci.toml"}\n' > "$b/path.json"
                   printf 'version = "2"\n# name = "early-return" only in a comment\n[[linters.settings.revive.rules]]\nname = "file-length-limit"\narguments = [{ max = 450 }]\n' > "$REPO/.golangci.toml" ;;
        json)      rm -f "$REPO/.golangci.yaml"
                   printf '{"absolutePath":"/r/.golangci.json","path":".golangci.json"}\n' > "$b/path.json"
                   printf '{"version": "2", "linters": {"settings": {"revive": {"rules": [{"name": "file-length-limit", "arguments": [{"max": 450}]}]}}}}\n' > "$REPO/.golangci.json" ;;
        invalid)   printf 'jsonschema: "" does not validate with "/additionalProperties": additional properties '"'"'linters-settings'"'"' not allowed\nThe command is terminated due to an error: the configuration contains invalid elements\n' > "$b/verify.txt" ;;
        noschema)  printf 'Error: failed to get schema: Get "https://golangci-lint.run/jsonschema/golangci.jsonschema.json": dial tcp: lookup golangci-lint.run: no such host\n' > "$b/verify.txt" ;;
        reject)    printf 'Error: can'"'"'t load config: unsupported version of the configuration: ""\n' > "$b/reject.txt" ;;
        garbled)   for f in path default recommended repo; do printf 'Enabled by your configuration linters:\nfunlen: Checks for long functions.\n' > "$b/$f.json"; done ;;
      esac ;;
    python)
      _fake_bin ruff '
cfg=""; prev=""
for a in "$@"; do
  case "$a" in
    --isolated) cat "$d/default.txt"; exit 0 ;;
    */setup/ruff.toml) cat "$d/recommended.txt"; exit 0 ;;
  esac
  [ "$prev" = --config ] && cfg=$a
  prev=$a
done
if [ -n "$cfg" ] && [ -f "$d/$(basename "$cfg").out" ]; then cat "$d/$(basename "$cfg").out"; exit 0; fi
if [ -f "$d/reject.txt" ]; then cat "$d/reject.txt" >&2; exit 2; fi
cat "$d/repo.txt"'
      _fake_ruff_settings '' 5 E401 F401 > "$b/default.txt"
      _fake_ruff_settings ruff.toml 4 B006 C901 E401 F401 PLR0913 PLR1702 > "$b/recommended.txt"
      _fake_ruff_settings pyproject.toml 4 B006 C901 E401 F401 PLR0913 PLR1702 > "$b/repo.txt"
      printf '[tool.ruff.lint]\nextend-select = ["B006", "C901", "PLR0913", "PLR1702"]\n' > "$REPO/pyproject.toml"
      case "$mode" in
        missing) _fake_ruff_settings pyproject.toml 4 B006 C901 E401 F401 PLR1702 > "$b/repo.txt" ;;
        relaxed) _fake_ruff_settings pyproject.toml 7 B006 C901 E401 F401 PLR0913 PLR1702 > "$b/repo.txt" ;;
        tightened) _fake_ruff_settings pyproject.toml 3 B006 C901 E401 F401 PLR0913 PLR1702 > "$b/repo.txt" ;;
        reject)  printf 'ruff failed\n  Cause: Failed to parse pyproject.toml\n' > "$b/reject.txt" ;;
        garbled) for f in default recommended repo; do printf 'linter.rules.enabled = 3 rules\n' > "$b/$f.txt"; done ;;
      esac ;;
    typescript)
      b="$REPO/node_modules/.bin"
      _fake_bin eslint '
cfg=""; prev=""
for a in "$@"; do [ "$prev" = -c ] && cfg=$a; prev=$a; done
if [ -n "$cfg" ] && [ -f "$d/$(basename "$cfg").out" ]; then cat "$d/$(basename "$cfg").out"; exit 0; fi
if [ -f "$d/reject.txt" ]; then cat "$d/reject.txt" >&2; exit 2; fi
cat "$d/repo.json"' "$b"
      cp "$(_fake_setup eslint.config.ldd.mjs)" "$REPO/eslint.config.mjs"
      _fake_eslint_json "$mode" > "$b/repo.json"
      case "$mode" in
        reject)  rm -f "$REPO/eslint.config.mjs"
                 printf '\nOops! Something went wrong! :(\n\nESLint: 9.31.0\n\nESLint couldn'"'"'t find an eslint.config.(js|mjs|cjs) file.\n' > "$b/reject.txt" ;;
        garbled) printf 'Unexpected token < in JSON at position 0\n' > "$b/repo.json" ;;
        norules) printf '{\n  "languageOptions": {\n    "parser": "x"\n  },\n  "rules": {}\n}\n' > "$b/repo.json" ;;
        ignored) printf 'undefined\n' > "$b/repo.json" ;;
      esac ;;
  esac
}

# fake_doctor_strict <path> — a config file the doctor compares in place of the
# repository's own, written at $REPO/<path> after fake_doctor: the linter
# reports on it as it reports on the recommended config. The report is the
# file's name plus ".out" in the fake's directory; a file with no report is
# read as the repository's config.
fake_doctor_strict() {
  local p="$1" n b="$REPO/.bin"; n=$(basename "$p")
  mkdir -p "$REPO/$(dirname "$p")"
  case "$ROW" in
    go)         cp "$(_fake_setup golangci.yaml)" "$REPO/$p"; cp "$b/recommended.json" "$b/$n.out" ;;
    python)     cp "$(_fake_setup ruff.toml)" "$REPO/$p"; cp "$b/recommended.txt" "$b/$n.out" ;;
    typescript) cp "$(_fake_setup eslint.config.ldd.mjs)" "$REPO/$p"; _fake_eslint_json adopt > "$REPO/node_modules/.bin/$n.out" ;;
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
