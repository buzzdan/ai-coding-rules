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

installed_plugin_dir() {
  local f="${LDD_INSTALLED_PLUGINS:-$HOME/.claude/plugins/installed_plugins.json}"
  [[ -f "$f" ]] || return 0
  awk -v key="\"$1@" '
    index($0, key) { found = 1; next }
    found && /"installPath"/ { sub(/^[^:]*:[ \t]*"/, ""); sub(/".*$/, ""); print; exit }
  ' "$f"
}
# ================== end language table ==================
