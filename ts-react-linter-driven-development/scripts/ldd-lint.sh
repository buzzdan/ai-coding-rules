#!/usr/bin/env bash
# Gap linter of the ts-react-linter-driven-development plugin.
#
# Measures the design triggers no linter holds, or that the repository's linter
# does not hold yet: lines per source file and source files per directory. It
# never edits a file. Where the repository's linter has a file-length rule, the
# linter owns file length and this script leaves it alone. Its doctor compares
# the repository's linter with the plugin's recommended config.
#
# Usage:  bash scripts/ldd-lint.sh <subcommand> [options]
#   file-length            source files over the file-length limit
#   package-size           directories at or over the warning size or the limit
#   doctor                 per language of the repository, each rule of the
#                          plugin's recommended config under setup/: whether
#                          the repository's linter runs it, and the setting on
#                          both sides (below)
#   agree                  prints agreement-record lines for .ldd-lint.yaml,
#                          ready to copy unchanged (below)
#   --brief                doctor: the status nudge, one line per project, or
#                          nothing (below)
#   --root <dir>           the repository, or one project in it, such as a
#                          front end with its own linter config: every
#                          lookup starts there (default: cwd)
#   --files <list>         measure the source files this list names, one
#                          relative path per line (a scope bundle's files.txt
#                          works: a "(not bundled: …)" suffix is ignored);
#                          default: every source file of the repository
#   --tsv                  findings as rows: path TAB line TAB message, line 0;
#                          the threshold lines then go to stderr. doctor rows:
#                          language TAB linter TAB rule TAB state TAB
#                          recommended TAB current TAB source
#   --linter <name>        agree: the linter of the rule. With --config (doctor
#                          and agree): the linter that file is for, needed when
#                          the run reports two or more linters
#   --rule <name>          agree: the rule, as the doctor names it
#   --decision <d>         agree: current (keep the repository's setting), off
#                          or org (the organization owns the value)
#   --reason <text>        agree: why the team agreed
#   --fingerprint          agree: one line per config file the doctor compared,
#                          for each linter that reports no setting
#   --linters              agree: one line per linter this run reports and
#                          checked
#   --config <file>        doctor and agree: compare this config file in place of
#                          the repository's own, for one linter: the one that
#                          --linter names, else the one linter of the run (the
#                          path is relative to --root); it overrides the
#                          lint_config item of that linter
#   --lint-config <linter> <path>  agree: the line that names a config file
#                          for that linter
#   --glob <pattern>       source-file glob, for a language the table does not
#                          know (TypeScript + React block below)
#   --test-re <ERE>        test-file pattern over relative paths
#
# Thresholds, per language — the "threshold:" line says which one a run used:
#   file-length: when a linter config at the repository root names a
#      file-length rule, the linter holds it: the line names the rule and the
#      script measures nothing more. Else the limit is file_max_lines in
#      .ldd-lint.yaml, else the plugin's default, 450 code lines (blank and
#      comment-only lines are not counted); with the default, the line also
#      prints the linter setting that would hold the limit, as a proposal for
#      the repository's owners: a run of this script never edits a config
#   package-size: no linter counts files per directory. package_warn_files and
#      package_max_files in .ldd-lint.yaml, else the plugin's defaults: a
#      warning at 8 source files per directory and the limit at 13
#
# What is measured: the language's source files, minus test files, generated
# files and the directories the language block excludes. A directory count
# also leaves out the files the linter table names (an index module, a package
# marker, generated stubs, stories). Code lines are the lines that keep code
# once comments are removed; a comment marker inside a string literal is code.
# In a git repository an ignored file is never measured or counted, and a
# --files run counts each directory it names in full. A file is over the limit
# when its count is above it; a directory is in the warning zone at the
# warning size and over the limit at the limit.
#
# doctor: the rules are the ones the recommended config enables, as the
# installed linter resolves it, beyond the linter's default set, and the
# default rules the config names that the repository does not run. Each row
# has a state: agreed, runs, missing, limit looser or limit stricter (the
# repository's setting lets more code pass, or less, than the recommended
# one), options differ (the two settings differ in a way that is not one
# limit), named (the rule is named outside comments in the repository's
# config; the linter was not asked), or cannot verify, with the reason (the
# linter is not installed, or rejects a config). A row of rule "-" that cannot
# verify is about the whole linter: the doctor cannot check it. A row of a named
# rule that cannot verify is about that rule only: the installed linter does not
# report its setting, and the other rows of the linter stay. recommended and current are
# the setting as the linter reports it; where the linter cannot report it, they
# are "see <file>: <key>", the place a reader looks the value up; "-" is no
# setting. source is "linter" when the linter said whether the rule runs, and
# "presence check" when the rule was found by name. A linter output the doctor
# cannot read is "cannot verify", never an empty list. A "doctor:" line per
# language says which config was compared, and which linter binary ran. When
# the linter's own config check cannot run (for example, with no network for
# its schema), a "doctor:" line says that the linter did not check the config,
# with the linter's message, and the rows follow. The
# doctor runs a linter from PATH only, except a linter that a project installs
# in its node_modules: that check runs the project's own copy, which loads the
# project's config file.
#
# The agreement record is the file .ldd-lint.yaml, which the lint-setup skill
# writes. Its key "agreed" lists one item per rule the team agreed to keep. An
# item is one double-quoted YAML scalar: "<linter> <rule> = <value> | <reason>".
# A backslash and a quote in it are escaped. The value is the setting as the
# doctor shows it in current, or "off", or "org" (the organization owns it).
# The script also reads an item in single quotes ('' is a quote) or a plain
# item. A list skips blank lines and comment lines, and ends at the next key.
# Each other line under a key gives one warning on stderr, with the file and
# the line number, and is ignored; doctor --brief prints no warning. The
# keys "lint_config" and "lint_fingerprint" hold the config files the agreement
# was made against, and the key "linters" names the linters the setup covers:
#   lint_config       "<linter> <path>": the doctor compares that file for that
#                     linter, in place of the repository's own config, and the
#                     linter's own config check reads it too. --config overrides
#                     it. The doctor ignores an item of a linter the run does not
#                     report. An item whose path is not a file gives that linter
#                     one row, "cannot verify: the agreed config <path> does not
#                     exist".
#   lint_fingerprint  "<linter> <path> <hash>", for a linter that reports no
#                     setting: when the hash of the file is not the one in the
#                     item, or the file is gone, the doctor prints
#                     "doctor: <path> changed since the setup was agreed" on
#                     stderr, once per file. It ignores an item of a linter the
#                     run does not report, and an item of a linter that reports
#                     its settings: the rows of that linter show a changed value.
#   linters           "<linter>", one item per linter the setup covers, also a
#                     linter with no item in another key (a setup that took every
#                     recommended value has none). doctor --brief counts the rows
#                     of these linters, and of the linters that an item of the
#                     other keys names.
# A path in a record line is relative to the project root, also for a file
# above it ("../"), so the line reads the same in every clone.
#
# The doctor gives a row the state agreed when its rule is agreed and the
# agreed value is org, or:
#   a linter that reports settings: the rule runs and current equals the
#     agreed value, or the rule is missing and agreed off
#   a linter that reports no setting (it says only which rules run): the rule
#     runs and is agreed at any value but off, or it is missing and agreed off
# A row with another value keeps its state, and its current gains
# "; agreed: <value>". A row that cannot verify is never agreed.
#
# The doctor warns on stderr about an item of "agreed" whose linter the run
# reports with rows and whose rule has no row; it ignores that item. It does not
# warn about an item of a linter the run does not report, or of a linter that
# cannot verify. The warning does not change the exit code.
#
# agree prints, on stdout, one record line for the skill to copy into
# .ldd-lint.yaml unchanged. Each line is one escaped item:
#   agree --linter <l> --rule <r> --decision <d> --reason <text>
#       "<l> <r> = <value> | <reason>", where the value is the doctor's current
#       setting of that rule (current), off or org; every " | " in the reason
#       becomes " / ". It reads the doctor's rows, so the rule must have one.
#       A rule in the state missing has no setting: only off is accepted.
#   agree --fingerprint
#       "<linter> <path> <hash>" for each config file the doctor compared, of
#       each linter that reports no setting; a linter that reports its settings
#       gets no line. The hash is git hash-object of the file, else the first
#       field of cksum. When another file was chosen (--config or lint_config),
#       the repository's own config of that linter gets a line too, after the
#       chosen file's. A linter that reports no setting and has no config file
#       compared gets a note on stderr and no line
#   agree --lint-config <linter> <path>
#       "<linter> <path>"; the path must be a file
#   agree --linters
#       "<linter>" for each linter this run reports and checked, one line each.
#       A linter whose row of rule "-" is cannot verify gets no line. When no linter
#       gets a line, a note on stderr says why, and the exit is 0. Each linter
#       left out gets a note on stderr. A language
#       left to another installed plugin gives no line. It takes no value, and
#       it cannot combine with the rule options, --fingerprint or --lint-config
# A linter that cannot verify gives no row and no config: agree with the rule
# options exits 2 when that linter cannot verify, and agree --fingerprint exits 2
# when any linter in scope cannot verify. Each names the cause. agree --linters
# leaves that linter out and exits 0. A named rule whose own row cannot verify
# blocks only that rule: agree with the rule options exits 2 for it, names the
# setting and says to upgrade the linter. The other forms of agree go on.
#
# doctor --brief prints the status nudge. It finds the projects itself: the
# root and each directory with a tracked .ldd-lint.yaml (a find outside git).
# A project gets no line and no linter run when its .ldd-lint.yaml has no
# "agreed" key, or when the record names no linter. For the other projects, it
# runs "doctor --tsv" there and counts the rows of each linter that the record
# names: an item of linters, agreed, lint_fingerprint or lint_config. The other
# linters belong to a plugin whose setup did not run. It prints one line per
# project when the doctor finds a difference:
#   ⚙️ Lint setup (<dir>): 1 rule differs from what the team agreed — run /tsr-ldd-setup
#   ⚙️ Lint setup (<dir>): <n> rules differ from what the team agreed — run /tsr-ldd-setup
#   ⚙️ Lint setup (<dir>): the linter cannot check this project — run /tsr-ldd-setup
# <dir> is "." for the root and "<path>/" for a project below it. Each of these
# is one difference:
#   a row in the state missing or limit looser that is not agreed
#   a row of any state whose agreed value changed: its current ends in
#     "; agreed: <value>"
#   a config file that changed since the setup was agreed
# A row of rule "-" that cannot verify, for a cause that is the same in every
# clone (the linter rejects the config, the agreed config is gone), gives the
# last line in place of a count. A linter that is not installed on this machine,
# or not on PATH, gives no line: the line is about the team's setup, not one
# machine. The states runs, agreed, limit stricter, options differ and named,
# and a named rule that cannot verify, are no difference. A
# project whose doctor exits 2 or 3, or fails, gets no line. Only the lines
# print. --brief takes no --config and no --files, and always exits 0.
#
# The generic plugin's doctor leaves a language to the plugin written for it
# when that plugin is installed: it prints
#   doctor: <language> — <plugin> is installed and checks this language; run /<prefix>-setup
# and gives that language no row, no config and no agree line. The other plugins
# check their own language and never skip one this way.
#
# Exit codes:
#   0  measured, with or without findings; doctor --brief always
#   2  a usage error; a --files list that does not exist; a --config that is
#      not a file, or that meets a run with two or more linters and no
#      --linter; a --linter that names no linter of the run; a .ldd-lint.yaml
#      value that is not a positive integer; a doctor run with no language the
#      plugin recommends a config for (inconclusive, never silently clean); an
#      agree line the script cannot write: no doctor row for the rule, a
#      linter that cannot verify, a path that is not a file
#   3  a doctor run where the generic plugin left every language in scope to an
#      installed plugin written for it (nothing to research)
#
# Uses only POSIX-portable tools plus git when the root is a repository:
# grep, sed, awk, sort, find, head.

set -u

SCRIPT_NAME="ldd-lint"
PLUGIN_NAME="ts-react-linter-driven-development"
DEFAULT_FILE_MAX_LINES=450
DEFAULT_PACKAGE_WARN_FILES=8
DEFAULT_PACKAGE_MAX_FILES=13
OVERRIDE_FILE=".ldd-lint.yaml"
ROOT="$(pwd)"
FILES_LIST=""
TSV=0
OPT_GLOB=""
OPT_TEST_RE=""
SUBCOMMAND=""
AGREE_LINTER=""
AGREE_RULE=""
AGREE_DECISION=""
AGREE_REASON=""
AGREE_FINGERPRINT=0
AGREE_LINTERS=0
AGREE_CONFIG_LINTER=""
AGREE_CONFIG_PATH=""
AGREE_SET=""
LINTER_SET=0
OPT_CONFIG=""
CONFIG_LINTER=""
BRIEF=0

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "$SCRIPT_NAME: $*" >&2; exit 2; }

# value <option> <remaining argument count> — a value-taking option needs one
value() { (( $2 >= 2 )) || die "$1 needs a value"; }

while (( $# > 0 )); do
  case "$1" in
    file-length|package-size|doctor|agree) [[ -n "$SUBCOMMAND" ]] && die "one subcommand, got also: $1"; SUBCOMMAND="$1"; shift ;;
    --root)    value "$1" $#; ROOT="$2"; shift 2 ;;
    --files)   value "$1" $#; FILES_LIST="$2"; shift 2 ;;
    --tsv)     TSV=1; shift ;;
    --linter)   value "$1" $#; AGREE_LINTER="$2"; LINTER_SET=1; shift 2 ;;
    --rule)     value "$1" $#; AGREE_RULE="$2"; AGREE_SET="$AGREE_SET $1"; shift 2 ;;
    --decision) value "$1" $#; AGREE_DECISION="$2"; AGREE_SET="$AGREE_SET $1"; shift 2 ;;
    --reason)   value "$1" $#; AGREE_REASON="$2"; AGREE_SET="$AGREE_SET $1"; shift 2 ;;
    --fingerprint) AGREE_FINGERPRINT=1; AGREE_SET="$AGREE_SET $1"; shift ;;
    --linters)     AGREE_LINTERS=1; AGREE_SET="$AGREE_SET $1"; shift ;;
    --lint-config) (( $# >= 3 )) || die "$1 needs a linter and a path"
                   AGREE_CONFIG_LINTER="$2"; AGREE_CONFIG_PATH="$3"; AGREE_SET="$AGREE_SET $1"; shift 3 ;;
    --config)  value "$1" $#; OPT_CONFIG="$2"; shift 2 ;;
    --brief)   BRIEF=1; shift ;;
    --glob)    value "$1" $#; OPT_GLOB="$2"; shift 2 ;;
    --test-re) value "$1" $#; OPT_TEST_RE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *)         die "unknown argument: $1 (see --help)" ;;
  esac
done
[[ -n "$SUBCOMMAND" ]] || die "name a subcommand: file-length, package-size, doctor or agree (see --help)"
[[ -z "$AGREE_SET" || "$SUBCOMMAND" == agree ]] || die "only agree takes:$AGREE_SET"
[[ -z "$OPT_CONFIG" || "$SUBCOMMAND" == doctor || "$SUBCOMMAND" == agree ]] || die "only doctor and agree take --config"
(( ! LINTER_SET )) || [[ "$SUBCOMMAND" == agree || ( "$SUBCOMMAND" == doctor && -n "$OPT_CONFIG" ) ]] \
  || die "only agree, and doctor with --config, take --linter"
(( ! BRIEF )) || [[ "$SUBCOMMAND" == doctor ]] || die "only doctor takes --brief"
(( ! BRIEF )) || [[ -z "$OPT_CONFIG$FILES_LIST" ]] || die "--brief takes no --config or --files"
[[ -d "$ROOT" ]] || die "not a directory: $ROOT"
if [[ -n "$FILES_LIST" ]]; then
  [[ -f "$FILES_LIST" ]] || die "no such file list: $FILES_LIST"
  [[ "$FILES_LIST" == /* ]] || FILES_LIST="$(pwd)/$FILES_LIST"
fi
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SETUP_DIR="$(cd "$(dirname "$0")/.." && pwd)/setup"
cd "$ROOT" || exit 2
[[ -z "$OPT_CONFIG" || -f "$OPT_CONFIG" ]] || die "--config: not a file: $OPT_CONFIG"

# ==================== language table ====================
# How a file's language is told, and which plugin owns a language. The same
# table is rendered into every plugin, so two plugins that split one scope
# agree on every file. The language block below says which of these ids this
# plugin reviews itself; the rest are routed to the plugin that owns them.
# residue-exempt: the table names every language's extension and plugin on
# purpose, the same in every rendering.
#
#   lang_of_path <path>       the language id of a source file, by extension:
#                             "custom" for a file matching --glob (then nothing
#                             else is a source file), "" for a file that is not
#                             source (a manifest, a doc, a build file)
#   dedicated_plugin_for <id> the plugin written for that language, or ""
#   GENERIC_PLUGIN            the plugin that reviews any language
#   plugin_cmd_prefix <name>  the prefix of that plugin's commands, as in
#                             /<prefix>-setup
#   installed_plugin_dir <n>  where plugin <n> is installed, from the
#                             installed-plugins file, or "" when it is not;
#                             LDD_INSTALLED_PLUGINS names another file
GENERIC_PLUGIN='linter-driven-development'

# A .h header is C++ when the repository has C++ sources, C otherwise.
HEADER_LANG=""
header_lang() {
  [[ -n "$HEADER_LANG" ]] && { printf '%s' "$HEADER_LANG"; return; }
  if { git ls-files -- '*.cpp' '*.cc' '*.cxx' '*.hpp' 2>/dev/null || find . -type f \( -name '*.cpp' -o -name '*.cc' -o -name '*.cxx' -o -name '*.hpp' \) -not -path './.git/*' 2>/dev/null; } | head -1 | grep -q .; then
    HEADER_LANG=cpp
  else
    HEADER_LANG=c
  fi
  printf '%s' "$HEADER_LANG"
}

lang_of_path() {
  local b="${1##*/}"
  if [[ -n "${OPT_GLOB:-}" ]]; then
    case "$b" in $OPT_GLOB) printf 'custom' ;; esac
    return 0
  fi
  case "$b" in
    *.go)                                   printf 'go' ;;
    *.py)                                   printf 'python' ;;
    *.d|*.di)                               printf 'd' ;;
    *.rs)                                   printf 'rust' ;;
    *.c)                                    printf 'c' ;;
    *.h)                                    header_lang ;;
    *.cpp|*.cc|*.cxx|*.hpp|*.hh|*.hxx)      printf 'cpp' ;;
    *.java)                                 printf 'java' ;;
    *.kt|*.kts)                             printf 'kotlin' ;;
    *.rb)                                   printf 'ruby' ;;
    *.sh|*.bash)                            printf 'shell' ;;
    *.ts|*.tsx)                             printf 'typescript' ;;
    *.js|*.jsx|*.mjs|*.cjs)                 printf 'javascript' ;;
    *.cs)                                   printf 'csharp' ;;
  esac
  return 0
}

dedicated_plugin_for() {
  case "$1" in
    go|python)              printf '%s-linter-driven-development' "$1" ;;
    typescript|javascript)  printf 'ts-react-linter-driven-development' ;;
  esac
  return 0
}

plugin_cmd_prefix() {
  case "$1" in
    go-linter-driven-development)        printf 'go-ldd' ;;
    python-linter-driven-development)    printf 'py-ldd' ;;
    ts-react-linter-driven-development)  printf 'tsr-ldd' ;;
    *)                                   printf 'ldd' ;;
  esac
  return 0
}

installed_plugin_dir() {
  local f="${LDD_INSTALLED_PLUGINS:-$HOME/.claude/plugins/installed_plugins.json}"
  [[ -f "$f" ]] || return 0
  awk -v key="\"$1@" '
    index($0, key) { found = 1; next }
    found && /"installPath"/ { sub(/^[^:]*:[ \t]*"/, ""); sub(/".*$/, ""); print; exit }
  ' "$f"
}
# ================== end language table ==================

# ===================== language block: ts-react =====================
# Everything language-specific the review scripts need. The driver calls only
# the LANG_* variables and lang_* functions defined here; a build of the script
# for another language replaces this block and nothing else. Which file is
# which language is the language table above, shared by every plugin.
#
# Contract:
#   LANG_NATIVE         the language ids this plugin reviews itself; a group of
#                       any other id is routed to the plugin that owns it
#   lang_configure <id> sets the variables below for that id; "custom" is the
#                       --glob override, reviewed with this block's defaults;
#                       exit 2 for an id this block has no row for
#   LANG_EXCLUDE_RE     ERE over a relative path: directories never in scope
#   LANG_SUPPRESS_RE    ERE: a lint-suppression directive on a source line
#   LANG_COMMENT_RE     ERE: a source line that carries a comment
#                       (bracket expressions, no backslashes: the driver hands it to
#                       awk -v, which eats `\*` and `\s` under gawk)
#   LANG_DIRECTIVE_RE   ERE: a comment line that is a directive, not prose
#   LANG_GENERATED_RE   ERE: a marker in a file's head that says it is generated
#   lang_is_test <path> exit 0 iff the path is a test file (--test-re overrides)
#
# The table sends `.ts` and `.tsx` here as typescript and `.js`, `.jsx`, `.mjs`
# and `.cjs` as javascript; both are reviewed with the same row. Declaration
# files, the `*.generated.ts(x)` modules a code generator writes, and build
# output are dropped by the exclude pattern.
LANG_NATIVE="typescript javascript custom"

lang_configure() {
  case "$1" in typescript|javascript|custom) ;; *) return 2 ;; esac
  LANG_EXCLUDE_RE='(^|/)(node_modules|dist|build|\.next|coverage|\.git|storybook-static)/|\.d\.ts$|\.generated\.[jt]sx?$'
  LANG_SUPPRESS_RE='eslint-disable(-next-line|-line)?|@ts-(expect-error|ignore|nocheck)|prettier-ignore'
  LANG_COMMENT_RE='//|/[*]|^[[:space:]]*[*]'
  LANG_DIRECTIVE_RE='eslint-(disable|enable)|@ts-(expect-error|ignore|nocheck|check)|prettier-ignore|/// <reference|@vitest-environment|istanbul ignore|c8 ignore|biome-ignore'
  LANG_GENERATED_RE='Generated by|DO NOT EDIT|@generated|automatically generated'
  return 0
}

# Stories (`*.stories.tsx`) are not production code either: Storybook renders
# them, nothing ships them, so their sleeps and doubles are judged as a test's.
lang_is_test() {
  [[ -n "${OPT_TEST_RE:-}" ]] && { printf '%s\n' "$1" | grep -qE -- "$OPT_TEST_RE"; return; }
  case "$1" in
    *.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx|*.stories.tsx|*.test.js|*.test.jsx|*.spec.js|*.spec.jsx) return 0 ;;
    __tests__/*|*/__tests__/*|test-utils/*|*/test-utils/*|tests/*|*/tests/*|e2e/*|*/e2e/*) return 0 ;;
  esac
  return 1
}
# =================== end language block: ts-react ===================

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

# ---------- output ----------
# A threshold line is for the reader of the report; with --tsv the rows are
# the output and the threshold lines go to stderr.
say() { if (( TSV )); then printf '%s\n' "$*" >&2; else printf '%s\n' "$*"; fi; }
finding() { # <path> <message>
  if (( TSV )); then printf '%s\t0\t%s\n' "$1" "$2"; else printf '%s: %s\n' "$1" "$2"; fi
}

# ---------- the repository override ----------
# override <key> — the key's value in .ldd-lint.yaml, "" when absent; a value
# that is not a positive integer ends the run, because the file is the
# repository's own statement of its limits.
override() {
  [[ -f "$OVERRIDE_FILE" ]] || return 0
  local v
  v=$(awk -v k="$1" -v q="'" '
    { line = $0; sub(/#.*/, "", line) }
    line ~ "^[[:space:]]*" k "[[:space:]]*:" {
      sub("^[[:space:]]*" k "[[:space:]]*:[[:space:]]*", "", line)
      gsub("[\"" q "[:space:]]", "", line)
      print line; exit
    }' "$OVERRIDE_FILE")
  [[ -z "$v" ]] && return 0
  [[ "$v" =~ ^[0-9]+$ ]] && (( v > 0 )) || die "$OVERRIDE_FILE: $1 must be a positive integer, got: $v"
  printf '%s' "$v"
}

# ---------- the agreement record ----------
# The record is the flat lists of .ldd-lint.yaml; this script reads no other
# structure from it. An item is one double-quoted scalar on a line "- ".

# record_has <key> — exit 0 when the record has the key, with items or as "[]"
record_has() {
  [[ -f "$OVERRIDE_FILE" ]] && grep -qE -- "^$1[[:space:]]*:" "$OVERRIDE_FILE"
}

# record_items <key> — each item of the key's list, unquoted and unescaped,
# one per line; nothing when the key or the file is absent. An item is a line
# "- <value>", with or without an indent. The value is double-quoted, with a
# backslash that escapes the next character; or single-quoted, with '' for a
# quote; or plain, up to a " #" comment. The list skips blank lines and comment
# lines, and ends at the next line that starts in column 0 and is not an item:
# the next key. A "#" inside the quotes is data. Each other line under the key
# gives one warning on stderr, with the file and the line number, and is
# ignored. With LINT_TMP set, a run warns once per key.
record_items() {
  [[ -f "$OVERRIDE_FILE" ]] || return 0
  local warn=1 mark=""
  if [[ -n "${LINT_TMP:-}" ]]; then
    mark="$LINT_TMP/warned.$1"
    [[ -e "$mark" ]] && warn=0
    : > "$mark"
  fi
  awk -v k="$1" -v w="$warn" -v q="'" '
    function skip(why) {
      if (w) print FILENAME " line " NR ": " why " of the list " k "; the line is ignored" | "cat 1>&2"
    }
    # item(rest) — the value of an item, or "\n" (no value) when the line is
    # not a whole item
    function item(s,   out, i, c, n) {
      c = substr(s, 1, 1); n = length(s); out = ""
      if (c == "\"") {
        for (i = 2; i <= n; i++) {
          c = substr(s, i, 1)
          if (c == "\\" && i < n) { out = out substr(s, ++i, 1); continue }
          if (c == "\"") break
          out = out c
        }
      } else if (c == q) {
        for (i = 2; i <= n; i++) {
          c = substr(s, i, 1)
          if (c == q && substr(s, i + 1, 1) == q) { out = out q; i++; continue }
          if (c == q) break
          out = out c
        }
      } else {
        sub(/[ \t]#.*$/, "", s); sub(/[ \t]+$/, "", s)
        if (s == "" || c == "#") return "\n"
        return s
      }
      if (i > n || substr(s, i + 1) !~ /^([ \t]+(#.*)?)?$/) return "\n"
      return out
    }
    on && /^[ \t]*$/ { next }
    on && /^[ \t]*#/ { next }
    on && /^[ \t]*-([ \t]|$)/ {
      rest = $0; sub(/^[ \t]*-[ \t]*/, "", rest)
      v = item(rest)
      if (v == "\n") skip("not a whole item"); else print v
      next
    }
    on && /^[ \t]/ { skip("not an item"); next }
    on { exit }
    $0 ~ "^" k "[ \t]*:" { on = 1 }
  ' "$OVERRIDE_FILE"
}

# record_linters — the linters the record names, one per line: each item of
# linters, and the first word of each item of agreed, lint_fingerprint and
# lint_config
record_linters() {
  { record_items linters; record_items agreed; record_items lint_fingerprint; record_items lint_config; } \
    | awk 'NF { print $1 }' | LC_ALL=C sort -u
}

# record_agreed <linter> <rule> — the agreed value of that rule, "" when the
# rule is not agreed. An item is "<linter> <rule> = <value> | <reason>": the
# rule runs to the first " = " and may hold a space; a reason may hold " | ",
# so the value ends at the first one.
record_agreed() {
  record_items agreed | LINTER="$1" RULE="$2" awk '
    {
      p = index($0, " = ")
      if (p == 0 || substr($0, 1, p - 1) != ENVIRON["LINTER"] " " ENVIRON["RULE"]) next
      v = substr($0, p + 3)
      q = index(v, " | ")
      print q ? substr(v, 1, q - 1) : v
      exit
    }'
}

# agreed_state <state> — exit 0 when a row in that state can turn agreed
agreed_state() {
  case "$1" in
    runs|missing|"limit looser"|"limit stricter"|"options differ"|named) return 0 ;;
  esac
  return 1
}

# agreed_by_value <state> <current> <value> — exit 0 when a row of a linter
# that reports settings is agreed: the value is org; or the rule is missing and
# agreed off; or the rule runs and the value equals current. A missing rule has
# the current "-", so an item agreed at "-" for a rule that ran never agrees it.
agreed_by_value() {
  [[ "$3" == org ]] && return 0
  if [[ "$1" == missing ]]; then [[ "$3" == off ]]; else [[ "$2" == "$3" ]]; fi
}

# agreed_by_name <state> <value> — exit 0 when a row of a linter that reports
# no setting is agreed: the value is org, or the rule is missing and agreed off,
# or the rule runs and is agreed at any value but off
agreed_by_name() {
  [[ "$2" == org ]] && return 0
  if [[ "$1" == missing ]]; then [[ "$2" == off ]]; else [[ "$2" != off ]]; fi
}

# agreed_row <linter> <rule> <state> <recommended> <current> — prints the
# row's state and current, as the record changes them, joined by a tab
agreed_row() {
  local v=""
  [[ -f "$OVERRIDE_FILE" ]] && v=$(record_agreed "$1" "$2")
  if [[ -z "$v" ]] || ! agreed_state "$3"; then printf '%s\t%s\n' "$3" "$5"; return 0; fi
  if lint_reports_settings "$1"; then
    agreed_by_value "$3" "$5" "$v" && { printf 'agreed\t%s\n' "$5"; return 0; }
  else
    agreed_by_name "$3" "$v" && { printf 'agreed\t%s\n' "$5"; return 0; }
  fi
  printf '%s\t%s; agreed: %s\n' "$3" "$5" "$v"
}

# record_line <text> — prints the text as one record item: a double-quoted
# scalar on a line "  - ", with a backslash and a quote escaped
record_line() {
  local t="$1"
  t=${t//\\/\\\\}; t=${t//\"/\\\"}
  printf '  - "%s"\n' "$t"
}

# ---------- doctor --brief ----------
# brief_projects — the projects of the run, one directory per line: the root,
# then each directory with a tracked record file
brief_projects() {
  printf '.\n'
  { if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git -c core.quotepath=off ls-files -- "*/$OVERRIDE_FILE"
    else
      find . -mindepth 2 -type f -name "$OVERRIDE_FILE" -not -path './.git/*' -not -path '*/node_modules/*' 2>/dev/null | sed 's|^\./||'
    fi
  } | sed 's|/[^/]*$||' | LC_ALL=C sort -u
}

# brief_line <dir> — the nudge line of one project; nothing when the project
# has no record, when the record names no linter, when its doctor does not exit
# 0, or when nothing differs. Only the rows of a linter that the record names
# count: the other linters belong to a plugin whose setup did not run. A linter
# that cannot verify counts only for a cause that is the same in every clone:
# a linter that is not installed on this machine gives no line. The
# changed-config count reads the doctor's own stderr line, so the text of that
# line and the pattern below stay equal.
brief_line() {
  local d="$1" out code differ cannot changed label what named err="$LINT_TMP/brief-err"
  (cd "$d" 2>/dev/null && record_has agreed) || return 0
  named=$(cd "$d" && record_linters 2>/dev/null | tr '\n' ' ')
  [[ -n "$named" ]] || return 0
  out=$("$BASH" "$SELF" doctor --tsv --root "./$d" 2>"$err"); code=$?
  (( code == 0 )) || return 0
  differ=$(printf '%s\n' "$out" | NAMED="$named" awk -F'\t' '
    BEGIN { n = split(ENVIRON["NAMED"], a, " "); for (i = 1; i <= n; i++) named[a[i]] = 1; n = 0 }
    !($2 in named) { next }
    $4 == "missing" || $4 == "limit looser" || $6 ~ /; agreed: / { n++ }
    END { print n + 0 }')
  # a linter that cannot verify, for a cause that is the same in every clone
  cannot=0
  while IFS= read -r st; do
    lint_cannot_local "$st" || cannot=$(( cannot + 1 ))
  done < <(printf '%s\n' "$out" | NAMED="$named" awk -F'\t' '
    BEGIN { n = split(ENVIRON["NAMED"], a, " "); for (i = 1; i <= n; i++) named[a[i]] = 1 }
    ($2 in named) && $3 == "-" && $4 ~ /^cannot verify/ { print $4 }')
  changed=$(grep -c '^doctor: .* changed since the setup was agreed$' "$err")
  differ=$(( differ + changed ))
  label="$d"; [[ "$d" == . ]] || label="$d/"
  if (( cannot > 0 )); then
    what="the linter cannot check this project"
  elif (( differ == 1 )); then
    what="1 rule differs from what the team agreed"
  elif (( differ > 1 )); then
    what="$differ rules differ from what the team agreed"
  else
    return 0
  fi
  printf '⚙️ Lint setup (%s): %s — run /tsr-ldd-setup\n' "$label" "$what"
}

run_brief() {
  local d
  while IFS= read -r d; do brief_line "$d"; done < <(brief_projects)
  exit 0
}

# ---------- the scope ----------
# SCOPE: one "id TAB path" line per source file the run measures. INVENTORY:
# the same for every source file of the repository, which a directory count
# reads, so a scoped run still counts a directory's files outside its list.
# Both come from git when the root is a repository, so an ignored file is in
# neither. Sorted, so two runs over one tree print the same thing.
list_repo() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files -co --exclude-standard
  else
    find . -type f -not -path './.git/*' | sed 's|^\./||'
  fi
}

list_candidates() {
  if [[ -n "$FILES_LIST" ]]; then
    sed -e 's/ (not bundled:.*$//' -e 's|^\./||' "$FILES_LIST"
  else
    list_repo
  fi
}

# by_language — reads paths, prints "id TAB path" for this plugin's languages
by_language() {
  local f id
  while IFS= read -r f; do
    [[ -n "$f" && -f "$f" ]] || continue
    id=$(lang_of_path "$f")
    [[ -n "$id" ]] || continue
    case " $LANG_NATIVE " in *" $id "*) ;; *) continue ;; esac
    printf '%s\t%s\n' "$id" "$f"
  done | LC_ALL=C sort -u
}

SCOPE=$(mktemp)
INVENTORY=$(mktemp)
LINT_TMP=$(mktemp -d)
trap 'rm -rf "$SCOPE" "$INVENTORY" "$LINT_TMP"' EXIT
(( ! BRIEF )) || run_brief
list_candidates | by_language > "$SCOPE"
if [[ -n "$FILES_LIST" ]]; then list_repo | by_language > "$INVENTORY"; else cp "$SCOPE" "$INVENTORY"; fi

# dir_of <path> — the directory part of a relative path, "." for a file at
# the root. A function, because bash 3.2 misreads a case pattern's ")" inside
# a process substitution.
dir_of() {
  case "$1" in
    */*) printf '%s\n' "${1%/*}" ;;
    *)   printf '.\n' ;;
  esac
}

# measured <path> — exit 0 when the file counts for this language: not under
# an excluded directory, not a test, not generated. Every path the script
# hands to find, head or awk starts with "./", and a directory is cut from a
# path by parameter expansion, so a name that starts with "-" is never read as
# an option.
measured() {
  printf '%s\n' "$1" | grep -qE -- "$LANG_EXCLUDE_RE" && return 1
  lang_is_test "$1" && return 1
  head -20 "./$1" 2>/dev/null | grep -qE -- "$LANG_GENERATED_RE" && return 1
  return 0
}

# ---------- file-length ----------
# code_lines <id> <path> — the lines that keep code after comments are removed
code_lines() {
  lint_strip_comments "$(lint_comment_style "$1")" "./$2" | awk 'NF { n++ } END { print n + 0 }'
}

run_file_length() { # <id> — every measured file of that language
  local id="$1" rule max src f n o
  rule=$(lint_file_length_rule "$id")
  if [[ -n "$rule" ]]; then
    say "threshold: $id file length — held by $rule; the repository's linter reports long files, so this script measures none"
    return 0
  fi
  o=$(override file_max_lines) || exit 2
  if [[ -n "$o" ]]; then
    max="$o"; src="$OVERRIDE_FILE"
    say "threshold: $id file length — set by $OVERRIDE_FILE ($max code lines)"
  else
    max="$DEFAULT_FILE_MAX_LINES"; src="profile default"
    say "threshold: $id file length — profile default ($max code lines); the repository's linter does not hold it; $(lint_file_length_proposal "$id")"
  fi
  while IFS=$'\t' read -r _ f; do
    measured "$f" || continue
    n=$(code_lines "$id" "$f")
    (( n > max )) && finding "$f" "$n code lines (limit $max, $src)"
  done < <(awk -F'\t' -v id="$id" '$1 == id' "$SCOPE")
}

# ---------- package-size ----------
run_package_size() { # <id> — every directory that holds a measured file of that language
  local id="$1" warn lim src ow om skip d n
  ow=$(override package_warn_files) || exit 2
  om=$(override package_max_files) || exit 2
  warn="${ow:-$DEFAULT_PACKAGE_WARN_FILES}"; lim="${om:-$DEFAULT_PACKAGE_MAX_FILES}"
  (( warn < lim )) || die "$OVERRIDE_FILE: package_warn_files ($warn) must be below package_max_files ($lim)"
  if [[ -n "$ow$om" ]]; then src="$OVERRIDE_FILE"; else src="profile default"; fi
  say "threshold: $id package size — $src (warning at $warn source files per directory, limit $lim); no linter counts files per directory"
  skip=$(lint_package_skip_re "$id")
  local counts; counts=$(mktemp)
  # one "dir TAB count" line per directory of the inventory
  awk -F'\t' -v id="$id" '$1 == id { print $2 }' "$INVENTORY" | while IFS= read -r f; do
    [[ -n "$skip" ]] && printf '%s\n' "$f" | grep -qE -- "$skip" && continue
    measured "$f" || continue
    dir_of "$f"
  done | LC_ALL=C sort | uniq -c | awk '{ n = $1; sub(/^[ \t]*[0-9]+[ \t]/, ""); print $0 "\t" n }' > "$counts"
  while IFS= read -r d; do
    n=$(awk -F'\t' -v d="$d" '$1 == d { print $2; exit }' "$counts")
    n="${n:-0}"
    if (( n >= lim )); then
      finding "$d" "$n source files (limit $lim, $src)"
    elif (( n >= warn )); then
      finding "$d" "$n source files (warning at $warn, $src)"
    fi
  done < <(awk -F'\t' -v id="$id" '$1 == id { print $2 }' "$SCOPE" | while IFS= read -r f; do
             measured "$f" && dir_of "$f"
           done | LC_ALL=C sort -u)
  rm -f "$counts"
}

# ---------- doctor ----------
# root_relative <path> — the path from the working directory, which is the
# project root: an absolute path gets "../" steps when it is above the root; a
# relative path stays as it is, without a leading "./". A record that holds the
# path then reads the same in every clone.
root_relative() {
  local p="$1" dir base root up=""
  [[ "$p" == /* ]] || { printf '%s' "${p#./}"; return 0; }
  base=${p##*/}
  dir=$(cd -P "${p%/*}/" 2>/dev/null && pwd -P) || { printf '%s' "$p"; return 0; }
  root=$(pwd -P)
  while [[ "$dir" != "$root" && "$dir" != "$root"/* && "$root" != / ]]; do
    root=$(dirname "$root"); up="../$up"
  done
  if [[ "$dir" == "$root" ]]; then printf '%s%s' "$up" "$base"
  elif [[ "$root" == / ]]; then printf '%s%s/%s' "$up" "${dir#/}" "$base"
  else printf '%s%s/%s' "$up" "${dir#"$root"/}" "$base"; fi
}

DOCTOR_DONE=""
# The run keeps what agree and the unmatched-line warning read: one line per
# row, "linter TAB rule TAB state TAB current" with the current setting as the
# linter reports it, before the record changes it; and one line per config
# file the doctor compared, "linter TAB path".
DOCTOR_ROWS="$LINT_TMP/rows"
DOCTOR_CONFIGS="$LINT_TMP/configs"
row() { # <id> <linter> <rule> <state> <recommended> <current> <source>
  if (( TSV )); then printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@"
  else printf '%s %s %s: %s; recommended: %s; current: %s; source: %s\n' "$@"; fi
}

# sample_file <id> — the source file a linter resolves its config for, the
# first that fits best: a measured file in a subdirectory that is not a
# tool's own config (*.config.*), outside hidden directories (a linter may
# skip those); else a measured file outside hidden directories; else a
# measured file; else any file of the language
sample_file() {
  local f first="" measured_one="" plain=""
  while IFS= read -r f; do
    [[ -z "$first" ]] && first="$f"
    measured "$f" || continue
    [[ -z "$measured_one" ]] && measured_one="$f"
    [[ "/$f" == */.* ]] && continue
    [[ -z "$plain" ]] && plain="$f"
    [[ "$f" == */* && "${f##*/}" != *.config.* ]] && { printf '%s' "$f"; return 0; }
  done < <(awk -F'\t' -v id="$1" '$1 == id { print $2 }' "$SCOPE")
  printf '%s' "${plain:-${measured_one:-$first}}"
}

# config_for <linter> — the config file the doctor compares for that linter:
# --config when it applies to that linter, else the linter's item of
# lint_config; nothing when there is none
config_for() {
  if [[ -n "$OPT_CONFIG" && ( -z "$CONFIG_LINTER" || "$1" == "$CONFIG_LINTER" ) ]]; then
    printf '%s' "$OPT_CONFIG"; return 0
  fi
  record_items lint_config | L="$1" awk '
    { p = index($0, " ")
      if (p == 0 || substr($0, 1, p - 1) != ENVIRON["L"]) next
      print substr($0, p + 1); exit }'
}

# left_to_plugin <id> — exit 0 when this is the generic plugin and the plugin
# written for the language is installed: that plugin checks the language
left_to_plugin() {
  [[ "$PLUGIN_NAME" == "$GENERIC_PLUGIN" ]] || return 1
  local d; d=$(dedicated_plugin_for "$1")
  [[ -n "$d" && -n "$(installed_plugin_dir "$d")" ]]
}

# run_doctor <id> — exit 0 when the language has a recommended config, 1 when
# it has none, 3 when an installed plugin checks the language instead
run_doctor() {
  local id="$1" linter kind a b c d e f other
  if left_to_plugin "$id"; then
    other=$(dedicated_plugin_for "$id")
    say "doctor: $id — $other is installed and checks this language; run /$(plugin_cmd_prefix "$other")-setup"
    return 3
  fi
  linter=$(lint_doctor_linter "$id")
  if [[ -z "$linter" ]]; then
    say "doctor: $id — the plugin recommends no linter config for this language"
    return 1
  fi
  case " $DOCTOR_DONE " in *" $linter "*) return 0 ;; esac
  # one linter serves both: a TypeScript repository is reported as typescript
  [[ "$id" == javascript ]] && printf '%s\n' "$ids" | grep -qx typescript && return 0
  DOCTOR_DONE="$DOCTOR_DONE $linter"
  while IFS=$'\t' read -r kind a b c d e f; do
    case "$kind" in
      note) say "doctor: $id — $a" ;;
      row)  printf '%s\t%s\t%s\t%s\n' "$a" "$b" "$c" "$e" >> "$DOCTOR_ROWS"
            IFS=$'\t' read -r c e < <(agreed_row "$a" "$b" "$c" "$d" "$e")
            row "$id" "$a" "$b" "$c" "$d" "$e" "$f" ;;
      config) printf '%s\t%s\n' "$a" "$(root_relative "$b")" >> "$DOCTOR_CONFIGS" ;;
    esac
  done < <(lint_doctor "$id" "$SETUP_DIR" "$(sample_file "$id")" "$(config_for "$linter")")
}

# warn_unmatched — a line on stderr for each item of "agreed" that names a
# linter this run reported and a rule it has no row for. An item of another
# linter belongs to another plugin's run, and a linter that cannot verify has
# no rows to match, so neither is named.
warn_unmatched() {
  [[ -s "$DOCTOR_ROWS" ]] || return 0
  local item head l r
  while IFS= read -r item; do
    [[ "$item" == *" = "* ]] || continue
    head=${item%% = *}
    [[ "$head" == *" "* ]] || continue
    l=${head%% *}; r=${head#* }
    [[ -n "$(L="$l" R="$r" awk -F'\t' '
      $1 == ENVIRON["L"] { seen = 1 }
      $1 == ENVIRON["L"] && $2 == "-" && $3 ~ /^cannot verify/ { cannot = 1 }
      $1 == ENVIRON["L"] && $2 == ENVIRON["R"] { matched = 1 }
      END { if (seen && !cannot && !matched) print "warn" }' "$DOCTOR_ROWS")" ]] \
      && echo "doctor: $OVERRIDE_FILE: no row for $l $r; the line is ignored" >&2
  done < <(record_items agreed)
  return 0
}

# report_changed — a line on stderr for each config file whose hash is not the
# one of its item of "lint_fingerprint", or that is gone. An item is
# "<linter> <path> <hash>": the path may hold a space, the hash is the last
# word. An item of a linter this run did not report belongs to another plugin's
# run, so it is not checked. An item of a linter that reports its settings is
# not checked either: its rows show a changed value, and a change elsewhere in
# the file (a dependency in a package manifest) is no drift.
report_changed() {
  [[ -s "$DOCTOR_ROWS" ]] || return 0
  local item rest linter path want
  while IFS= read -r item; do
    [[ "$item" == *" "*" "* ]] || continue
    linter=${item%% *}; rest=${item#* }
    want=${rest##* }; path=${rest% *}
    L="$linter" awk -F'\t' '$1 == ENVIRON["L"] { f = 1 } END { exit !f }' "$DOCTOR_ROWS" || continue
    lint_reports_settings "$linter" && continue
    if [[ ! -f "$path" || "$(file_hash "$path")" != "$want" ]]; then
      echo "doctor: $path changed since the setup was agreed" >&2
    fi
  done < <(record_items lint_fingerprint)
  return 0
}

# ---------- agree ----------
# file_hash <path> — git hash-object of the file, else the first field of cksum
file_hash() {
  git hash-object -- "$1" 2>/dev/null || cksum < "$1" | cut -d' ' -f1
}

# fingerprint_line <linter> <path> — the record line for one config file
fingerprint_line() {
  record_line "$1 $2 $(file_hash "$2")"
}

# agree_cannot [<linter>] — dies with the cause when the doctor could not
# verify that linter, or any linter: a "cannot verify" row of rule "-". A row
# of a named rule that cannot verify blocks that rule only.
agree_cannot() {
  local why
  why=$(L="${1:-}" awk -F'\t' '$2 == "-" && $3 ~ /^cannot verify/ && (ENVIRON["L"] == "" || $1 == ENVIRON["L"]) { print $1 " " $3; exit }' "$DOCTOR_ROWS")
  [[ -z "$why" ]] || die "agree: $why"
}

run_agree_rule() {
  local reason="$AGREE_REASON" value state sel
  [[ -n "$AGREE_LINTER" ]] || die "agree needs --linter"
  [[ -n "$AGREE_RULE" ]] || die "agree needs --rule"
  [[ -n "$AGREE_REASON" ]] || die "agree needs --reason, and it is empty"
  case "$AGREE_DECISION" in
    current|off|org) ;;
    *) die "agree needs --decision current, off or org, got: ${AGREE_DECISION:-nothing}" ;;
  esac
  agree_cannot "$AGREE_LINTER"
  sel=$(L="$AGREE_LINTER" R="$AGREE_RULE" awk -F'\t' '
    $1 == ENVIRON["L"] && $2 == ENVIRON["R"] { print $3 "\t" $4; found = 1; exit }
    END { exit !found }' "$DOCTOR_ROWS") || die "agree: no doctor row for $AGREE_LINTER $AGREE_RULE"
  state=${sel%%$'\t'*}; value=${sel#*$'\t'}
  [[ "$state" != "cannot verify"* ]] \
    || die "agree: $AGREE_LINTER $AGREE_RULE $state; the installed linter cannot report this setting: upgrade the linter"
  [[ "$AGREE_DECISION" == current && "$state" == missing ]] \
    && die "agree: $AGREE_LINTER $AGREE_RULE does not run, so it has no setting to keep; use --decision off"
  [[ "$AGREE_DECISION" == current ]] || value="$AGREE_DECISION"
  reason=${reason//$'\n'/ }; reason=${reason//$'\r'/ }; reason=${reason//$'\t'/ }
  while [[ "$reason" == *" | "* ]]; do reason=${reason/ | / / }; done
  record_line "$AGREE_LINTER $AGREE_RULE = $value | $reason"
}

# run_agree_fingerprint — the lines of the linters that report no setting; a
# linter that reports its settings shows a changed value in its rows
run_agree_fingerprint() {
  local linter path
  agree_cannot
  [[ ! -s "$DOCTOR_CONFIGS" ]] || while IFS=$'\t' read -r linter path; do
    lint_reports_settings "$linter" || fingerprint_line "$linter" "$path"
  done < "$DOCTOR_CONFIGS"
  # a linter the run reports, with no config file compared: no line, and a note
  while IFS= read -r linter; do
    lint_reports_settings "$linter" && continue
    L="$linter" awk -F'\t' '$1 == ENVIRON["L"] { f = 1 } END { exit !f }' "$DOCTOR_CONFIGS" 2>/dev/null \
      || echo "agree: no config file of $linter was compared, so there is no fingerprint line for it" >&2
  done < <(cut -f1 "$DOCTOR_ROWS" | LC_ALL=C sort -u)
  return 0
}

# run_agree_linters — one line per linter that has rows in this run and no row
# that cannot verify; a note on stderr for each linter left out, and one more
# when no linter gets a line
run_agree_linters() {
  local linter named=0 skipped=""
  if [[ -s "$DOCTOR_ROWS" ]]; then
    while IFS= read -r linter; do
      if L="$linter" awk -F'\t' '$1 == ENVIRON["L"] && $2 == "-" && $3 ~ /^cannot verify/ { f = 1 } END { exit !f }' "$DOCTOR_ROWS"; then
        skipped="$skipped $linter"
        echo "agree: $linter cannot be checked, so there is no linters line for it" >&2
        continue
      fi
      record_line "$linter"; named=1
    done < <(cut -f1 "$DOCTOR_ROWS" | LC_ALL=C sort -u)
  fi
  (( named )) || echo "agree: no linter of this run could be checked, so there is no linters line${skipped:+ (cannot verify:$skipped)}" >&2
  return 0
}

# ---------- run ----------
if [[ "$SUBCOMMAND" == agree ]]; then
  # with --config, --linter names the linter of that file, so alone it is no
  # rule option
  modes=$(( AGREE_FINGERPRINT + AGREE_LINTERS ))
  [[ -n "$AGREE_CONFIG_LINTER" ]] && modes=$(( modes + 1 ))
  rule_opts=0
  (( LINTER_SET )) && [[ -z "$OPT_CONFIG" ]] && rule_opts=1
  for o in --rule --decision --reason; do
    case " $AGREE_SET " in *" $o "*) rule_opts=1 ;; esac
  done
  modes=$(( modes + rule_opts ))
  (( modes <= 1 )) || die "agree takes one of --fingerprint, --lint-config, --linters or the rule options"
  [[ -z "$AGREE_CONFIG_LINTER" ]] || (( ! LINTER_SET )) || die "agree --lint-config takes no --linter"
  if [[ -n "$AGREE_CONFIG_LINTER" ]]; then
    [[ -f "$AGREE_CONFIG_PATH" ]] || die "agree --lint-config: not a file: $AGREE_CONFIG_PATH"
    record_line "$AGREE_CONFIG_LINTER $(root_relative "$AGREE_CONFIG_PATH")"
    exit 0
  fi
fi
ids=$(cut -f1 "$SCOPE" | LC_ALL=C sort -u)
if [[ -z "$ids" ]]; then
  say "$SCRIPT_NAME: no source file in scope"
  [[ "$SUBCOMMAND" == doctor || "$SUBCOMMAND" == agree ]] && exit 2
  exit 0
fi
[[ "$SUBCOMMAND" != doctor && "$SUBCOMMAND" != agree || -d "$SETUP_DIR" ]] || die "no recommended configs at $SETUP_DIR"
# linter_names — the distinct linters this run reports, one per line; a
# language left to another installed plugin has none
linter_names() {
  local id
  for id in $ids; do
    left_to_plugin "$id" && continue
    lint_doctor_linter "$id"; printf '\n'
  done | awk 'NF && !seen[$0]++'
}
# CONFIG_LINTER — the linter --config applies to: the one of --linter, else the
# one linter of the run
if [[ -n "$OPT_CONFIG" ]]; then
  names=$(linter_names | tr '\n' ' '); names=${names% }
  if (( LINTER_SET )); then
    case " $names " in
      *" $AGREE_LINTER "*) CONFIG_LINTER=$AGREE_LINTER ;;
      *) die "--linter $AGREE_LINTER: this run reports no such linter; it reports: ${names:-no linter}" ;;
    esac
  elif [[ "$names" == *" "* ]]; then
    die "--config needs --linter <name> in a run with two or more linters; this run reports: $names"
  else
    CONFIG_LINTER=$names
  fi
fi
checked=0 left=0 no_config=0
# tally_doctor <status of run_doctor> — counts the language by what the doctor did
tally_doctor() {
  case "$1" in
    0) checked=1 ;;
    3) left=1 ;;
    *) no_config=1 ;;
  esac
}
for id in $ids; do
  lang_configure "$id" || continue
  case "$SUBCOMMAND" in
    file-length)  run_file_length "$id" ;;
    package-size) run_package_size "$id" ;;
    doctor)       run_doctor "$id"; tally_doctor $? ;;
    agree)        run_doctor "$id" > /dev/null 2>&1; tally_doctor $? ;;
  esac
done
if [[ "$SUBCOMMAND" == doctor ]] && (( ! checked )); then
  (( left && ! no_config )) && exit 3
  say "doctor: no language in scope has a recommended linter config"
  exit 2
fi
if [[ "$SUBCOMMAND" == agree ]]; then
  if (( ! checked )); then
    (( left && ! no_config )) && die "agree: every language in scope belongs to an installed plugin; run its setup command"
    die "agree: no language in scope has a recommended linter config"
  fi
  if (( AGREE_LINTERS )); then run_agree_linters
  elif (( AGREE_FINGERPRINT )); then run_agree_fingerprint
  else run_agree_rule; fi
  exit 0
fi
if [[ "$SUBCOMMAND" == doctor ]]; then warn_unmatched; report_changed; fi
exit 0
