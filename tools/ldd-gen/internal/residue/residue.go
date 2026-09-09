// Package residue finds language-specific text left in core/. Hard tokens are
// names a binding scalar or include should have replaced, so one is a missed
// substitution. Soft tokens are inline idioms (nil, ctx, goroutine) that a
// second language binding will have to resolve; their report is the backlog
// for that binding, written into core/README.md between two markers.
package residue

import (
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"regexp"
	"sort"
	"strings"
)

// BeginMarker and EndMarker mark where the generated Residue section of
// core/README.md starts and ends.
const (
	BeginMarker = "<!-- residue:begin -->"
	EndMarker   = "<!-- residue:end -->"
)

// README.md holds this report, so scanning it would hit its own output.
const coreReadme = "README.md"

// Token is one pattern the scan looks for, named the way the report shows it.
type Token struct {
	Name string
	re   *regexp.Regexp
}

func token(name, pattern string) Token {
	return Token{Name: name, re: regexp.MustCompile(pattern)}
}

// HardTokens are names a profile scalar or an include already replaces; a hit
// is a missed substitution and fails lint-core.
func HardTokens() []Token {
	return []Token{
		token("plugin name literal", `go-linter-driven-development`),
		token("command prefix literal", `\bgo-ldd\b`),
		token("golangci", `golangci`),
		token("*.go glob", `\*\.go\b`),
		token("_test.go", `_test\.go`),
		token("//nolint", `//nolint`),
	}
}

// SoftTokens are reported, never fatal.
func SoftTokens() []Token {
	return []Token{
		token("Go code fence", "```go"),
		token("go.mod", `go\.mod`),
		token(".go suffix", `\.go\b`),
		token("go test / go vet", `\bgo (test|vet)\b`),
		token("godoc", `godoc`),
		token("Go (the word)", `\bGo\b`),
		token("Go linter name", `\b(errcheck|bodyclose|govet|exhaustive|gocognit|gocyclo|funlen|nestif|ireturn|dupl|gochecknoglobals|gochecknoinits|maintidx|cyclop|wrapcheck|goconst|varnamelen|misspell|revive)\b`),
		token("Go library", `\b(testify|golang\.org/|errgroup)\b`),
		token("nil", `\bnil\b`),
		token("goroutine", `goroutine`),
		token("ctx", `\bctx\b`),
		token("context.", `\bcontext\.`),
		token("sync.", `\bsync\.`),
		token("pkg_test", `pkg_test`),
		token("func", `\bfunc `),
		token("struct", `\bstruct\b`),
		token("interface", `\binterface\b`),
		token("init()", `\binit\(\)`),
		token("wantErr", `wantErr`),
		token("httptest", `httptest`),
	}
}

// Hit is one token found on one line of one core file.
type Hit struct {
	Path  string
	Line  int
	Token string
	Text  string
}

// Report is the result of a scan, hard and soft hits kept apart.
type Report struct {
	Hard []Hit
	Soft []Hit
}

// Scan walks every file under core except its README and records each token
// hit. Attributed quotes in maxims.md (lines starting with an em dash) are
// exempt: a quoted Go proverb is portable text.
func Scan(core fs.FS) (Report, error) {
	var r Report
	err := fs.WalkDir(core, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || path == coreReadme {
			return err
		}
		data, err := fs.ReadFile(core, path)
		if err != nil {
			return fmt.Errorf("read %s: %w", path, err)
		}
		r.scanFile(path, string(data))
		return nil
	})
	if err != nil {
		return Report{}, fmt.Errorf("residue: %w", err)
	}
	r.sort()
	return r, nil
}

func (r *Report) scanFile(path, text string) {
	exemptQuotes := path == "maxims.md"
	hard, soft := HardTokens(), SoftTokens()
	for i, line := range strings.Split(text, "\n") {
		if exemptQuotes && strings.HasPrefix(line, "— ") {
			continue
		}
		r.Hard = append(r.Hard, hitsOn(hard, path, i+1, line)...)
		r.Soft = append(r.Soft, hitsOn(soft, path, i+1, line)...)
	}
}

func hitsOn(tokens []Token, path string, n int, line string) []Hit {
	var hits []Hit
	for _, t := range tokens {
		if t.re.MatchString(line) {
			hits = append(hits, Hit{Path: path, Line: n, Token: t.Name, Text: strings.TrimSpace(line)})
		}
	}
	return hits
}

func (r *Report) sort() {
	sortHits(r.Hard)
	sortHits(r.Soft)
}

func sortHits(h []Hit) {
	sort.SliceStable(h, func(i, j int) bool {
		if h[i].Path != h[j].Path {
			return h[i].Path < h[j].Path
		}
		if h[i].Line != h[j].Line {
			return h[i].Line < h[j].Line
		}
		return h[i].Token < h[j].Token
	})
}

// Markdown renders the report as the body of the README's Residue section:
// the hard hits line by line (they must reach zero), then soft hits counted
// per token and per file.
func (r Report) Markdown() string {
	var b strings.Builder
	writeHard(&b, r.Hard)
	byToken := grouping{
		title: "Soft residue by token", column: "Token", detail: "Files",
		rowKey: func(h Hit) string { return h.Token }, countedValue: func(h Hit) string { return h.Path },
	}
	byFile := grouping{
		title: "Soft residue by file", column: "File", detail: "Tokens",
		rowKey: func(h Hit) string { return "`" + h.Path + "`" }, countedValue: func(h Hit) string { return h.Token },
	}
	writeCounts(&b, r.Soft, byToken)
	writeCounts(&b, r.Soft, byFile)
	return b.String()
}

func writeHard(b *strings.Builder, hits []Hit) {
	if len(hits) == 0 {
		fmt.Fprint(b, "Hard residue: none. No plugin-name or command-prefix literal, golangci\nreference, source-file glob or nolint directive is left in core/.\n")
		return
	}
	fmt.Fprintf(b, "Hard residue (%d) — each is a missed substitution:\n\n", len(hits))
	for _, h := range hits {
		fmt.Fprintf(b, "- `%s:%d` %s: `%s`\n", h.Path, h.Line, h.Token, h.Text)
	}
}

type grouping struct {
	title        string
	column       string
	detail       string
	rowKey       func(Hit) string
	countedValue func(Hit) string
}

// writeCounts prints one table: per row key, the number of distinct lines
// that carry a hit, and the number of distinct counted values behind them.
func writeCounts(b *strings.Builder, hits []Hit, g grouping) {
	lines := map[string]map[string]bool{}
	values := map[string]map[string]bool{}
	allLines := map[string]bool{}
	for _, h := range hits {
		k := g.rowKey(h)
		line := fmt.Sprintf("%s:%d", h.Path, h.Line)
		addTo(lines, k, line)
		addTo(values, k, g.countedValue(h))
		allLines[line] = true
	}
	keys := sortedKeys(lines)
	fmt.Fprintf(b, "\n%s (%d lines):\n\n| %s | Lines | %s |\n|---|---:|---:|\n", g.title, len(allLines), g.column, g.detail)
	for _, k := range keys {
		fmt.Fprintf(b, "| %s | %d | %d |\n", k, len(lines[k]), len(values[k]))
	}
}

func addTo(sets map[string]map[string]bool, key, value string) {
	if sets[key] == nil {
		sets[key] = map[string]bool{}
	}
	sets[key][value] = true
}

// sortedKeys orders rows by line count, largest first, then by name.
func sortedKeys(lines map[string]map[string]bool) []string {
	keys := make([]string, 0, len(lines))
	for k := range lines {
		keys = append(keys, k)
	}
	sort.Slice(keys, func(i, j int) bool {
		if len(lines[keys[i]]) != len(lines[keys[j]]) {
			return len(lines[keys[i]]) > len(lines[keys[j]])
		}
		return keys[i] < keys[j]
	})
	return keys
}

// WriteReadme replaces the text between the two markers in the README at path
// with the report. The markers must both be present, in order. An unchanged
// README is left untouched, so a repeated run never dirties the checkout.
func WriteReadme(path string, r Report) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("residue: %w", err)
	}
	updated, err := Splice(data, r.Markdown())
	if err != nil {
		return err
	}
	if bytes.Equal(updated, data) {
		return nil
	}
	if err := os.WriteFile(path, updated, 0o644); err != nil {
		return fmt.Errorf("residue: %w", err)
	}
	return nil
}

// Splice returns readme with the section between the markers replaced by body.
func Splice(readme []byte, body string) ([]byte, error) {
	begin := bytes.Index(readme, []byte(BeginMarker))
	end := bytes.Index(readme, []byte(EndMarker))
	if begin < 0 || end < 0 || end < begin {
		return nil, errors.New("residue: README lacks the residue markers")
	}
	var out bytes.Buffer
	out.Write(readme[:begin+len(BeginMarker)])
	out.WriteString("\n" + body)
	out.Write(readme[end:])
	return out.Bytes(), nil
}
