package residue_test

import (
	"os"
	"path/filepath"
	"strings"
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
		{Path: "rules/R1.md", Line: 2, Token: "goroutine", Text: "A goroutine and a nil."},
		{Path: "rules/R1.md", Line: 2, Token: "nil", Text: "A goroutine and a nil."},
	}, r.Soft, "sorted by path, line, then token")
}

func scanLine(t *testing.T, line string) residue.Report {
	t.Helper()
	r, err := residue.Scan(fstest.MapFS{"x.md": {Data: []byte(line + "\n")}})
	require.NoError(t, err)
	return r
}

func TestHardTokens(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name string
		line string
		want string // token name, or "" when the line must be clean
	}{
		{name: "plugin name with colon", line: "Skill(go-linter-driven-development:testing)", want: "plugin name literal"},
		{name: "plugin name bare", line: "see go-linter-driven-development/rules", want: "plugin name literal"},
		{name: "command prefix", line: "run /go-ldd-review", want: "command prefix literal"},
		{name: "golangci", line: "`.golangci.yaml`", want: "golangci"},
		{name: "source glob", line: "--include='*.go'", want: "*.go glob"},
		{name: "test suffix", line: "in `*_test.go` files", want: "_test.go"},
		{name: "nolint", line: "never add //nolint", want: "//nolint"},
		{name: "near miss glob", line: "*.gold files", want: ""},
		{name: "near miss nolint", line: "the nolint prohibition", want: ""},
		{name: "near miss prefix", line: "a go-lddx thing", want: ""},
		{name: "template scalar", line: "Skill({{.Plugin}}:testing) and /{{.CmdPrefix}}-review", want: ""},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			r := scanLine(t, tc.line)
			if tc.want == "" {
				assert.Empty(t, r.Hard)
				return
			}
			require.Len(t, r.Hard, 1)
			assert.Equal(t, tc.want, r.Hard[0].Token)
		})
	}
}

func TestSoftTokens_LinterAndLibraryNames(t *testing.T) {
	t.Parallel()
	r := scanLine(t, "the `exhaustive` linter and testify")
	var names []string
	for _, h := range r.Soft {
		names = append(names, h.Token)
	}
	assert.ElementsMatch(t, []string{"Go linter name", "Go library"}, names)
}

func TestMarkdown(t *testing.T) {
	t.Parallel()
	r := residue.Report{
		Soft: []residue.Hit{
			{Path: "a.md", Line: 1, Token: "nil"},
			{Path: "a.md", Line: 1, Token: "ctx"},
			{Path: "a.md", Line: 2, Token: "nil"},
			{Path: "b.md", Line: 1, Token: "ctx"},
		},
	}
	md := r.Markdown()
	assert.Contains(t, md, "Hard residue: none.")
	assert.Contains(t, md, "Soft residue by token (3 lines)", "a line with two tokens counts once")
	tokenTable := strings.TrimSpace(md[strings.Index(md, "| Token |"):strings.Index(md, "Soft residue by file")])
	assert.Equal(t, "| Token | Lines | Files |\n|---|---:|---:|\n| ctx | 2 | 2 |\n| nil | 2 | 1 |", tokenTable, "ordered by lines, then name")
	assert.Contains(t, md, "| File | Lines | Tokens |")
	assert.Contains(t, md, "| `a.md` | 2 | 2 |")
	assert.Contains(t, md, "| `b.md` | 1 | 1 |")
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

	info, err := os.Stat(path)
	require.NoError(t, err)
	require.NoError(t, os.Chmod(path, 0o444))
	require.NoError(t, residue.WriteReadme(path, residue.Report{}), "an unchanged README is not rewritten")
	again, err := os.Stat(path)
	require.NoError(t, err)
	assert.Equal(t, info.ModTime(), again.ModTime())
}

func TestWriteReadme_Errors(t *testing.T) {
	t.Parallel()
	require.Error(t, residue.WriteReadme(filepath.Join(t.TempDir(), "missing.md"), residue.Report{}))
	path := filepath.Join(t.TempDir(), "README.md")
	require.NoError(t, os.WriteFile(path, []byte("no markers\n"), 0o644))
	require.Error(t, residue.WriteReadme(path, residue.Report{}))
}

func TestSplice_Errors(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name   string
		readme string
	}{
		{name: "no markers", readme: "no markers"},
		{name: "reversed markers", readme: residue.EndMarker + "\n" + residue.BeginMarker + "\n"},
		{name: "only begin", readme: residue.BeginMarker + "\n"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, err := residue.Splice([]byte(tc.readme), "body")
			require.Error(t, err)
		})
	}
}
