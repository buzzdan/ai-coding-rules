# ======================= language block: go =======================
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
#   LANG_DIRECTIVE_RE   ERE: a comment line that is a directive, not prose
#   LANG_GENERATED_RE   ERE: a marker in a file's head that says it is generated
#   lang_is_test <path> exit 0 iff the path is a test file (--test-re overrides)
LANG_NATIVE="go custom"

lang_configure() {
  case "$1" in go|custom) ;; *) return 2 ;; esac
  LANG_EXCLUDE_RE='(^|/)(vendor|\.git|testdata)/'
  LANG_SUPPRESS_RE='//nolint'
  LANG_COMMENT_RE='//'
  LANG_DIRECTIVE_RE='//(go:|nolint| Output:|line |export |extern )'
  LANG_GENERATED_RE='Code generated .* DO NOT EDIT|DO NOT EDIT|@generated'
  return 0
}

lang_is_test() {
  [[ -n "${OPT_TEST_RE:-}" ]] && { printf '%s\n' "$1" | grep -qE -- "$OPT_TEST_RE"; return; }
  [[ "$1" == *_test.go ]]
}
# ===================== end language block: go =====================
