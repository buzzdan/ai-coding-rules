package check_test

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/check"
	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/render"
)

func none(string) bool { return false }

func ignoreEvalsTree(rel string) bool { return strings.HasPrefix(rel, "evals/") }

func sample() render.Tree {
	return render.Tree{
		"README.md":       {Data: []byte("readme\n")},
		"rules/R1.md":     {Data: []byte("r1\n")},
		"hooks/hook.sh":   {Data: []byte("#!/bin/sh\n"), Exec: true},
		"evals/README.md": {Data: []byte("pointer\n")},
	}
}

func write(t *testing.T, dir, rel, content string) {
	t.Helper()
	path := filepath.Join(dir, rel)
	require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o755))
	require.NoError(t, os.WriteFile(path, []byte(content), 0o644))
}

func TestWriteThenCompare_Identical(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	require.NoError(t, check.Write(sample(), dir, none))
	diffs, err := check.Compare(sample(), dir, none)
	require.NoError(t, err)
	assert.Empty(t, diffs)
	info, err := os.Stat(filepath.Join(dir, "hooks/hook.sh"))
	require.NoError(t, err)
	assert.NotZero(t, info.Mode()&0o111)
}

func TestCompare_MissingDirIsAllMissing(t *testing.T) {
	t.Parallel()
	diffs, err := check.Compare(render.Tree{"a.md": {}}, filepath.Join(t.TempDir(), "nope"), none)
	require.NoError(t, err)
	assert.Equal(t, []check.Difference{{Path: "a.md", Kind: check.Missing}}, diffs)
}

func TestCompare_Differences(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	require.NoError(t, check.Write(sample(), dir, none))
	write(t, dir, "rules/R1.md", "edited\n")
	write(t, dir, "rules/R2.md", "extra\n")
	write(t, dir, "evals/cases/x/prompt.md", "ignored\n")
	write(t, dir, "evals/README.md", "pointer edited\n")
	require.NoError(t, os.Remove(filepath.Join(dir, "README.md")))
	require.NoError(t, os.Chmod(filepath.Join(dir, "hooks/hook.sh"), 0o644))

	diffs, err := check.Compare(sample(), dir, ignoreEvalsTree)
	require.NoError(t, err)
	assert.Equal(t, []check.Difference{
		{Path: "README.md", Kind: check.Missing},
		{Path: "evals/README.md", Kind: check.Changed},
		{Path: "hooks/hook.sh", Kind: check.ExecChanged},
		{Path: "rules/R1.md", Kind: check.Changed},
		{Path: "rules/R2.md", Kind: check.Extra},
	}, diffs, "a generated file inside an ignored directory is still compared")
}

func TestWrite_RemovesStaleKeepsIgnored(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	write(t, dir, "old/stale.md", "stale\n")
	write(t, dir, "evals/cases/x/prompt.md", "keep\n")
	require.NoError(t, os.MkdirAll(filepath.Join(dir, "evals/results"), 0o755))
	write(t, dir, "hooks/hook.sh", "old hook\n")

	require.NoError(t, check.Write(sample(), dir, ignoreEvalsTree))

	assert.NoFileExists(t, filepath.Join(dir, "old/stale.md"))
	assert.NoDirExists(t, filepath.Join(dir, "old"))
	assert.FileExists(t, filepath.Join(dir, "evals/cases/x/prompt.md"))
	assert.DirExists(t, filepath.Join(dir, "evals/results"), "an empty ignored directory is left alone")
	info, err := os.Stat(filepath.Join(dir, "hooks/hook.sh"))
	require.NoError(t, err)
	assert.NotZero(t, info.Mode()&0o111)
	diffs, err := check.Compare(sample(), dir, ignoreEvalsTree)
	require.NoError(t, err)
	assert.Empty(t, diffs)
}

func TestReport(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	write(t, dir, "rules/R1.md", "on disk\n")
	tree := render.Tree{"rules/R1.md": {Data: []byte("rendered\n")}}
	diffs := []check.Difference{
		{Path: "rules/R1.md", Kind: check.Changed},
		{Path: "rules/R2.md", Kind: check.Extra},
	}
	var out bytes.Buffer
	check.Report(&out, diffs, tree, dir)
	assert.Contains(t, out.String(), "changed       rules/R1.md")
	assert.Contains(t, out.String(), "extra         rules/R2.md")
	assert.Contains(t, out.String(), "-on disk")
	assert.Contains(t, out.String(), "+rendered")
}

func TestReport_DiffUnavailable(t *testing.T) {
	t.Setenv("PATH", t.TempDir())
	dir := t.TempDir()
	write(t, dir, "a.md", "x\n")
	var out bytes.Buffer
	check.Report(&out, []check.Difference{{Path: "a.md", Kind: check.Changed}}, render.Tree{"a.md": {Data: []byte("y\n")}}, dir)
	assert.Contains(t, out.String(), "changed       a.md")
	assert.Contains(t, out.String(), "diff unavailable")
}
