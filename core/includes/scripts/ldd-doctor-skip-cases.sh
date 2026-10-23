# ==================== doctor cases: a language left to its plugin ====================
# The generic plugin's doctor skips a language when the plugin written for it is
# installed. The cases name the Go plugin and its commands on purpose, the same
# in every rendering; every other rendering skips them.
# residue-exempt: the cases name the Go plugin, its command prefix and its linter.
GENERIC_PLUGIN='linter-driven-development'

# installed_fixture <plugin> — an installed-plugins file that names that plugin
installed_fixture() {
  printf '{\n  "version": 2,\n  "plugins": {\n    "%s@fixture": [\n      {\n        "scope": "user",\n        "installPath": "%s",\n        "version": "test"\n      }\n    ]\n  }\n}\n' \
    "$1" "$REPO/plugin" > "$REPO/installed.json"
}

begin "doctor: the generic plugin leaves a language to the installed plugin written for it"
if [[ "$PLUGIN_NAME" != "$GENERIC_PLUGIN" ]]; then skip "only the generic plugin leaves a language to another plugin"; finish
else
  mkdir -p "$REPO/plugin"; installed_fixture go-linter-driven-development
  write_src "src/a.go" 1
  LDD_INSTALLED_PLUGINS="$REPO/installed.json" run_doctor --tsv
  expect_exit 3 && expect_has "doctor: go — go-linter-driven-development is installed and checks this language; run /go-ldd-setup" \
    && { [[ -z "$OUT" ]] || bad "stdout is not empty"; } && ok
  finish

  begin "doctor: a language with no recommended config still ends the generic doctor with exit 2"
  mkdir -p "$REPO/plugin"; installed_fixture go-linter-driven-development
  write_src "src/a.go" 1; write_src "src/b.rs" 1
  LDD_INSTALLED_PLUGINS="$REPO/installed.json" run_doctor
  expect_exit 2 && expect_has "run /go-ldd-setup" && expect_has "doctor: rust — the plugin recommends no linter config" \
    && expect_has "no language in scope has a recommended linter config" && ok
  finish

  begin "doctor: with no plugin installed the generic doctor checks the language itself"
  ROW=go; fake_doctor_row; write_src "src/a.go" 1; fake_doctor adopt; ROW=""
  run_doctor
  expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_RULE: $FAKE_RUNS;" && expect_not "is installed and checks this language" && ok
  finish

  begin "agree: a language left to an installed plugin gives no row and no line"
  mkdir -p "$REPO/plugin"; installed_fixture go-linter-driven-development
  write_src "src/a.go" 1
  LDD_INSTALLED_PLUGINS="$REPO/installed.json" run_agree --fingerprint
  expect_exit 2 && expect_has "belongs to an installed plugin" && { [[ -z "$OUT" ]] || bad "stdout is not empty"; } && ok
  finish

  begin "agree --linters: a language left to an installed plugin gives no line"
  mkdir -p "$REPO/plugin"; installed_fixture go-linter-driven-development
  write_src "src/a.go" 1
  LDD_INSTALLED_PLUGINS="$REPO/installed.json" run_agree --linters
  expect_exit 2 && expect_has "belongs to an installed plugin" && { [[ -z "$OUT" ]] || bad "stdout is not empty"; } && ok
  finish

  begin "agree --linters: a language left to an installed plugin is not printed beside another language"
  mkdir -p "$REPO/plugin"; installed_fixture go-linter-driven-development
  write_src "src/a.go" 1
  ROW=python; fake_doctor_row; write_src "src/a.py" 1; fake_doctor adopt; ROW=""
  LDD_INSTALLED_PLUGINS="$REPO/installed.json" run_agree --linters
  expect_exit 0 && expect_out "  - \"$FAKE_LINTER\"" && ok
  finish

  begin "doctor --config: a language left to an installed plugin is not a second linter"
  mkdir -p "$REPO/plugin"; installed_fixture go-linter-driven-development
  write_src "src/a.go" 1
  ROW=python; fake_doctor_row; write_src "src/a.py" 1; fake_doctor missing; fake_doctor_strict strict-cfg; ROW=""
  LDD_INSTALLED_PLUGINS="$REPO/installed.json" run_doctor --config strict-cfg
  r1=0; expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_RULE: $FAKE_RUNS;" && expect_has "the chosen config strict-cfg" && r1=1
  LDD_INSTALLED_PLUGINS="$REPO/installed.json" run_agree --config strict-cfg --linter "$FAKE_LINTER" --rule "$FAKE_RULE" --decision current --reason "kept"
  (( r1 )) && expect_exit 0 && expect_has "$FAKE_LINTER $FAKE_RULE = " && ok
  finish

  begin "--brief says nothing for a project whose every language is left to an installed plugin"
  mkdir -p "$REPO/plugin"; installed_fixture go-linter-driven-development
  write_src "src/a.go" 1
  write_record "agreed: []"
  LDD_INSTALLED_PLUGINS="$REPO/installed.json" run_brief
  expect_exit 0 && expect_out "" && ok
  finish
fi
# ================== end doctor cases: a language left to its plugin ==================
