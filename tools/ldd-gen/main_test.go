package main

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const profileYAML = `plugin: out-plugin
lang: Lang
cmd_prefix: p-ldd
src_glob: "*.p"
test_glob: "_test.p"
project_marker: p.mod
nolint: "#nolint"
comment_prefix: "#"
default_test: ptest
default_lint: plint
default_lint_fix: plint --fix
`

func write(t *testing.T, root, rel, content string) {
	t.Helper()
	path := filepath.Join(root, rel)
	require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o755))
	require.NoError(t, os.WriteFile(path, []byte(content), 0o644))
}

func miniRepo(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	write(t, root, "lang/p/profile.yaml", profileYAML)
	write(t, root, "core/README.md", "# Core\n\n<!-- residue:begin -->\n<!-- residue:end -->\n")
	write(t, root, "core/rules/R1.md", "{{.Lang}} rule\n")
	return root
}

func TestRun_GenerateThenCheck(t *testing.T) {
	t.Parallel()
	root := miniRepo(t)
	var out bytes.Buffer

	err := run([]string{"-root", root, "-check"}, &out)
	require.ErrorIs(t, err, errDifferences)
	assert.Contains(t, out.String(), "missing       rules/R1.md")

	require.NoError(t, run([]string{"-root", root, "-lang", "p"}, &out))

	out.Reset()
	require.NoError(t, run([]string{"-root", root, "-check"}, &out))
	assert.Contains(t, out.String(), "every plugin directory matches")
}

func TestRun_LintCore(t *testing.T) {
	t.Parallel()
	root := miniRepo(t)
	var out bytes.Buffer
	require.NoError(t, run([]string{"lint-core", "-root", root, "-write"}, &out))
	assert.Contains(t, out.String(), "Hard residue: none")
	readme, err := os.ReadFile(filepath.Join(root, "core/README.md"))
	require.NoError(t, err)
	assert.Contains(t, string(readme), "<!-- residue:begin -->\nHard residue: none")

	write(t, root, "core/rules/R2.md", "never add //nolint\n")
	out.Reset()
	err = run([]string{"lint-core", "-root", root}, &out)
	require.ErrorIs(t, err, errHardResidue)
	assert.Contains(t, out.String(), "rules/R2.md:1")
}

func TestRun_Errors(t *testing.T) {
	t.Parallel()
	root := miniRepo(t)
	cases := []struct {
		name string
		args []string
		want error
	}{
		{name: "no mode", args: []string{"-root", root}, want: errNoMode},
		{name: "check and lang together", args: []string{"-root", root, "-check", "-lang", "p"}, want: errBothModes},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			err := run(tc.args, &bytes.Buffer{})
			require.ErrorIs(t, err, tc.want)
		})
	}
}

func TestRun_BadFlagAndBadRoot(t *testing.T) {
	t.Parallel()
	require.Error(t, run([]string{"-nope"}, &bytes.Buffer{}))
	require.Error(t, run([]string{"lint-core", "-nope"}, &bytes.Buffer{}))
	require.Error(t, run([]string{"-root", t.TempDir(), "-check"}, &bytes.Buffer{}))
	require.Error(t, run([]string{"-root", t.TempDir(), "-lang", "p"}, &bytes.Buffer{}))
	require.Error(t, run([]string{"lint-core", "-root", t.TempDir()}, &bytes.Buffer{}))
}
