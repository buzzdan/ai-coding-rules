// Package detect lints the detect lines of the rules' falsifying questions:
// the machine-readable line beside each numbered question that the review's
// detection script (scripts/ldd-detect.sh in every plugin) runs over the
// scope. The script refuses a rule file it cannot parse, so the lint moves
// that failure to the generator, where the source files are edited.
package detect

import (
	"fmt"
	"io/fs"
	"path"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// The question files, in core and in every binding. A binding renders its own
// file when it has one and the core default otherwise, so both are linted.
const (
	coreQuestions = "core/includes/rules/*/falsifying-questions.md"
	langQuestions = "lang/*/rules/*/falsifying-questions.md"
)

// Problem is one lint finding, anchored to a line of a source file.
type Problem struct {
	Path string
	Line int
	Msg  string
}

func (p Problem) String() string {
	return fmt.Sprintf("%s:%d: %s", p.Path, p.Line, p.Msg)
}

// Lint reads every question file under repo and returns the problems found,
// sorted by path and line. It fails only on a file that cannot be read.
func Lint(repo fs.FS) ([]Problem, error) {
	var problems []Problem
	counts := map[string]map[string]int{} // rule -> path -> number of questions
	for _, pattern := range []string{coreQuestions, langQuestions} {
		paths, err := fs.Glob(repo, pattern)
		if err != nil {
			return nil, fmt.Errorf("detect: %w", err)
		}
		for _, p := range paths {
			data, err := fs.ReadFile(repo, p)
			if err != nil {
				return nil, fmt.Errorf("detect: %w", err)
			}
			items := parse(string(data))
			problems = append(problems, lintItems(p, items)...)
			rule := path.Base(path.Dir(p))
			if counts[rule] == nil {
				counts[rule] = map[string]int{}
			}
			counts[rule][p] = len(items)
		}
	}
	problems = append(problems, lintCounts(counts)...)
	sort.Slice(problems, func(i, j int) bool {
		if problems[i].Path != problems[j].Path {
			return problems[i].Path < problems[j].Path
		}
		return problems[i].Line < problems[j].Line
	})
	return problems, nil
}

// item is one numbered question with the detect lines found under it.
type item struct {
	number  int
	line    int // 1-based line of the "N. **" headline
	detects []detectLine
}

type detectLine struct {
	line int
	text string // the line with its indentation removed
}

var (
	// numberedBold is the headline shape the handbook extractor reads too:
	// a question is "N. **headline**" and nothing else opens an item.
	numberedBold = regexp.MustCompile(`^(\d+)\. \*\*`)
	detectRe     = regexp.MustCompile(`^\s*Detect(-[a-z]+)?:`)
	placeholder  = regexp.MustCompile(`<[A-Za-z][A-Za-z0-9 _-]*>`)
	gateRe       = regexp.MustCompile(`^Q\d+$`)
	contextRe    = regexp.MustCompile(`^context=\d+$`)
)

// parse splits the file into its numbered items. Text before the first item
// (a preamble paragraph) belongs to no item and carries no detect line.
func parse(text string) []item {
	var items []item
	for i, line := range strings.Split(text, "\n") {
		if m := numberedBold.FindStringSubmatch(line); m != nil {
			n, _ := strconv.Atoi(m[1]) // the pattern admits digits only
			items = append(items, item{number: n, line: i + 1})
			continue
		}
		if len(items) > 0 && detectRe.MatchString(line) {
			last := &items[len(items)-1]
			last.detects = append(last.detects, detectLine{line: i + 1, text: strings.TrimSpace(line)})
		}
	}
	return items
}

func lintItems(p string, items []item) []Problem {
	var problems []Problem
	for i, it := range items {
		if it.number != i+1 {
			problems = append(problems, Problem{p, it.line, fmt.Sprintf("question numbered %d where %d was expected", it.number, i+1)})
		}
		switch len(it.detects) {
		case 0:
			problems = append(problems, Problem{p, it.line, fmt.Sprintf("question %d has no detect line (Detect-grep, Detect-path, Detect-gate or Detect: judgment)", it.number)})
		case 1:
			if msg := lintDetect(it.detects[0].text); msg != "" {
				problems = append(problems, Problem{p, it.detects[0].line, fmt.Sprintf("question %d: %s", it.number, msg)})
			}
		default:
			problems = append(problems, Problem{p, it.detects[1].line, fmt.Sprintf("question %d has %d detect lines (exactly one)", it.number, len(it.detects))})
		}
	}
	return problems
}

// lintDetect checks one detect line and returns the problem, or "" when the
// line is well formed. The shapes mirror the script's parser exactly.
func lintDetect(text string) string {
	kind, rest, _ := strings.Cut(text, ":")
	kind = strings.TrimPrefix(strings.TrimPrefix(kind, "Detect"), "-")
	rest = strings.TrimSpace(rest)
	switch kind {
	case "":
		if rest != "judgment" {
			return fmt.Sprintf("a bare Detect: line says judgment and nothing else, got %q", rest)
		}
		return ""
	case "gate":
		if !gateRe.MatchString(rest) {
			return fmt.Sprintf("Detect-gate names the R9 gate's question as Q<n>, got %q", rest)
		}
		return ""
	case "grep", "path":
		return lintPattern(kind, rest)
	default:
		return fmt.Sprintf("unknown detect kind %q (grep, path, gate, or a bare Detect: judgment)", "Detect-"+kind)
	}
}

func lintPattern(kind, rest string) string {
	if !strings.HasPrefix(rest, "`") {
		return fmt.Sprintf("Detect-%s needs a backticked pattern, got %q", kind, rest)
	}
	end := strings.LastIndex(rest, "`")
	if end == 0 {
		return fmt.Sprintf("Detect-%s pattern has no closing backtick", kind)
	}
	pattern, flags := rest[1:end], strings.TrimSpace(rest[end+1:])
	if pattern == "" {
		return fmt.Sprintf("Detect-%s pattern is empty", kind)
	}
	if m := placeholder.FindString(pattern); m != "" {
		return fmt.Sprintf("Detect-%s pattern carries the placeholder %s; the scope is the script's, a pattern is literal", kind, m)
	}
	if _, err := regexp.Compile(pattern); err != nil {
		return fmt.Sprintf("Detect-%s pattern does not compile: %v", kind, err)
	}
	if kind == "path" && flags != "" {
		return fmt.Sprintf("Detect-path takes no flags, got %q", flags)
	}
	return lintFlags(flags)
}

func lintFlags(flags string) string {
	seen := map[string]bool{}
	for fl := range strings.FieldsSeq(flags) {
		name, _, _ := strings.Cut(fl, "=")
		if seen[name] {
			return fmt.Sprintf("flag %s given twice", name)
		}
		seen[name] = true
		switch {
		case fl == "files=src", fl == "files=test", fl == "files=all":
		case strings.HasPrefix(fl, "exclude-path=") && len(fl) > len("exclude-path="):
		case contextRe.MatchString(fl):
		default:
			return fmt.Sprintf("unknown detect flag %q (files=src|test|all, exclude-path=<ERE>,<ERE>, context=<n>)", fl)
		}
	}
	return ""
}

// lintCounts requires every file of one rule to carry the same number of
// questions: a binding that drops or adds a question breaks the per-question
// receipts the review reconciles by number.
func lintCounts(counts map[string]map[string]int) []Problem {
	var problems []Problem
	for rule, files := range counts {
		var paths []string
		for p := range files {
			paths = append(paths, p)
		}
		sort.Strings(paths)
		core, others := splitCore(paths)
		if core == "" {
			continue
		}
		for _, p := range others {
			if files[p] != files[core] {
				problems = append(problems, Problem{p, 1, fmt.Sprintf("%s carries %d questions here and %d in %s; every binding renders a detect line for each question of a rule", rule, files[p], files[core], core)})
			}
		}
	}
	return problems
}

func splitCore(paths []string) (string, []string) {
	var core string
	var others []string
	for _, p := range paths {
		if strings.HasPrefix(p, "core/") {
			core = p
		} else {
			others = append(others, p)
		}
	}
	return core, others
}
