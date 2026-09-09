package residue_test

import (
	"os"
	"path/filepath"
	"testing"
	"testing/fstest"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/residue"
)

func TestScan(t *testing.T) {
	t.Parallel()
	core := fstest.MapFS{
		"README.md":   {Data: []byte("golangci lives here and is not a hit\n")},
		"rules/R1.md": {Data: []byte("Run `golangci-lint run`.\nA goroutine and a nil.\nfine line\n")},
		"maxims.md":   {Data: []byte("— Rob Pike, Go Proverbs\nGo is mentioned here\n")},
	}
	r, err := residue.Scan(core)
	require.NoError(t, err)

	assert.Equal(t, []residue.Hit{
		{Path: "rules/R1.md", Line: 1, Token: "golangci", Text: "Run `golangci-lint run`."},
	}, r.Hard)
	assert.Equal(t, []residue.Hit{
		{Path: "maxims.md", Line: 2, Token: "Go (the word)", Text: "Go is mentioned here"},
		{Path: "rules/R1.md", Line: 2, Token: "nil", Text: "A goroutine and a nil."},
		{Path: "rules/R1.md", Line: 2, Token: "goroutine", Text: "A goroutine and a nil."},
	}, r.Soft)
}

func TestMarkdown(t *testing.T) {
	t.Parallel()
	r := residue.Report{
		Soft: []residue.Hit{
			{Path: "a.md", Line: 1, Token: "nil"},
			{Path: "a.md", Line: 2, Token: "nil"},
			{Path: "b.md", Line: 1, Token: "ctx"},
		},
	}
	md := r.Markdown()
	assert.Contains(t, md, "Hard residue: none.")
	assert.Contains(t, md, "| nil | 2 | 1 |")
	assert.Contains(t, md, "| ctx | 1 | 1 |")
	assert.Contains(t, md, "| `a.md` | 2 | 1 |")
	assert.Contains(t, md, "| File | Lines | Tokens |")
}

func TestMarkdown_Hard(t *testing.T) {
	t.Parallel()
	r := residue.Report{Hard: []residue.Hit{{Path: "a.md", Line: 3, Token: "golangci", Text: "x golangci y"}}}
	assert.Contains(t, r.Markdown(), "- `a.md:3` golangci: `x golangci y`")
}

func TestWriteReadme(t *testing.T) {
	t.Parallel()
	path := filepath.Join(t.TempDir(), "README.md")
	readme := "# Core\n\n## Residue\n\n" + residue.BeginMarker + "\nold\n" + residue.EndMarker + "\n\ntail\n"
	require.NoError(t, os.WriteFile(path, []byte(readme), 0o644))

	require.NoError(t, residue.WriteReadme(path, residue.Report{}))
	got, err := os.ReadFile(path)
	require.NoError(t, err)
	assert.Contains(t, string(got), residue.BeginMarker+"\nHard residue: none.")
	assert.Contains(t, string(got), residue.EndMarker+"\n\ntail\n")
	assert.NotContains(t, string(got), "old")
}

func TestSplice_NoMarkers(t *testing.T) {
	t.Parallel()
	_, err := residue.Splice([]byte("no markers"), "body")
	require.Error(t, err)
}
