package evalcase

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"

	"example.com/ldd-eval/internal/frontmatter"
	"example.com/ldd-eval/internal/grade"
)

// ErrBadGraderType is returned for an unknown grader `type:`.
var ErrBadGraderType = errors.New("evalcase: grader type must be regex, tool_used, tool_order, file_exists or llm")

type toolRef struct {
	Tool       string `yaml:"tool"`
	InputMatch string `yaml:"input_match"`
}

// graderFront is the union of every grader type's frontmatter; unknown keys
// are rejected by the decoder.
type graderFront struct {
	Type       string    `yaml:"type"`
	Pattern    string    `yaml:"pattern"`
	Flags      string    `yaml:"flags"`
	Match      string    `yaml:"match"`
	Target     string    `yaml:"target"`
	Tool       string    `yaml:"tool"`
	InputMatch string    `yaml:"input_match"`
	Min        *int      `yaml:"min"`
	Max        *int      `yaml:"max"`
	Before     *toolRef  `yaml:"before"`
	After      *toolRef  `yaml:"after"`
	Path       string    `yaml:"path"`
	Criteria   string    `yaml:"criteria"`
	Focus      yaml.Node `yaml:"focus"`
}

// loadGraderFiles parses every graders/*.md, sorted by filename. A missing
// graders dir yields no graders (the case may rely on postcheck alone).
func loadGraderFiles(dir string) ([]grade.Grader, error) {
	files, err := filepath.Glob(filepath.Join(dir, "*.md"))
	if err != nil {
		return nil, fmt.Errorf("glob graders: %w", err)
	}
	graders := make([]grade.Grader, 0, len(files))
	for _, f := range files {
		g, lerr := LoadGrader(f)
		if lerr != nil {
			return nil, lerr
		}
		graders = append(graders, g)
	}
	return graders, nil
}

// LoadGrader parses one graders/<name>.md into a grader named after the file.
func LoadGrader(file string) (grade.Grader, error) {
	data, err := os.ReadFile(file)
	if err != nil {
		return nil, fmt.Errorf("grader: %w", err)
	}
	doc, err := frontmatter.Parse(data)
	if err != nil {
		return nil, fmt.Errorf("grader %s: %w", file, err)
	}
	var fm graderFront
	if err := doc.Decode(&fm); err != nil {
		return nil, fmt.Errorf("grader %s: %w", file, err)
	}
	name := strings.TrimSuffix(filepath.Base(file), ".md")
	g, err := fm.build(name, doc.Body())
	if err != nil {
		return nil, fmt.Errorf("grader %s: %w", file, err)
	}
	return g, nil
}

func (fm graderFront) build(name, body string) (grade.Grader, error) {
	switch strings.TrimSpace(fm.Type) {
	case "regex":
		return wrap(grade.NewRegex(grade.RegexSpec{Name: name, Pattern: fm.Pattern, Flags: fm.Flags, Match: fm.Match, Target: fm.Target}))
	case "tool_used":
		return fm.buildToolUsed(name)
	case "tool_order":
		return fm.buildToolOrder(name)
	case "file_exists":
		return wrap(grade.NewFileExists(name, fm.Path))
	case "llm":
		return fm.buildLLM(name, body)
	default:
		return nil, fmt.Errorf("%w: got %q", ErrBadGraderType, fm.Type)
	}
}

// wrap adapts a concrete constructor result to the Grader interface, wrapping
// its error with the grader-file context.
func wrap[G grade.Grader](g G, err error) (grade.Grader, error) {
	if err != nil {
		return nil, fmt.Errorf("build grader: %w", err)
	}
	return g, nil
}

func (fm graderFront) buildToolUsed(name string) (grade.Grader, error) {
	sel, err := grade.NewToolSelector(fm.Tool, fm.InputMatch)
	if err != nil {
		return nil, fmt.Errorf("tool_used: %w", err)
	}
	bounds, err := grade.NewBounds(orDefault(fm.Min, 1), orDefault(fm.Max, 0), fm.Max != nil)
	if err != nil {
		return nil, fmt.Errorf("tool_used: %w", err)
	}
	return wrap(grade.NewToolUsed(name, sel, bounds))
}

func (fm graderFront) buildToolOrder(name string) (grade.Grader, error) {
	if fm.Before == nil || fm.After == nil {
		return nil, fmt.Errorf("tool_order needs before and after: %w", grade.ErrEmptyTool)
	}
	before, err := grade.NewToolSelector(fm.Before.Tool, fm.Before.InputMatch)
	if err != nil {
		return nil, fmt.Errorf("tool_order before: %w", err)
	}
	after, err := grade.NewToolSelector(fm.After.Tool, fm.After.InputMatch)
	if err != nil {
		return nil, fmt.Errorf("tool_order after: %w", err)
	}
	return wrap(grade.NewToolOrder(name, before, after))
}

func (fm graderFront) buildLLM(name, body string) (grade.Grader, error) {
	focus, err := parseFocus(fm.Focus)
	if err != nil {
		return nil, err
	}
	return wrap(grade.NewLLM(name, fm.Criteria, body, focus))
}

// parseFocus accepts the scalar `last_message` (or nothing) or the mapping
// `{source: file, path: <rel>}`.
func parseFocus(node yaml.Node) (grade.Focus, error) {
	switch node.Kind {
	case yaml.ScalarNode:
		return parseScalarFocus(node.Value)
	case yaml.MappingNode:
		return parseMappingFocus(node)
	case yaml.DocumentNode, yaml.SequenceNode, yaml.AliasNode:
		return grade.Focus{}, fmt.Errorf("%w: got a %v node", grade.ErrBadFocus, node.Kind)
	default: // zero Kind: the focus key is absent
		return grade.FocusLastMessage(), nil
	}
}

func parseScalarFocus(value string) (grade.Focus, error) {
	if v := strings.TrimSpace(value); v == "" || v == "last_message" {
		return grade.FocusLastMessage(), nil
	}
	return grade.Focus{}, fmt.Errorf("%w: got %q", grade.ErrBadFocus, value)
}

func parseMappingFocus(node yaml.Node) (grade.Focus, error) {
	var m struct {
		Source string `yaml:"source"`
		Path   string `yaml:"path"`
	}
	if err := node.Decode(&m); err != nil {
		return grade.Focus{}, fmt.Errorf("%w: %w", grade.ErrBadFocus, err)
	}
	if m.Source != "file" {
		return grade.Focus{}, fmt.Errorf("%w: source %q", grade.ErrBadFocus, m.Source)
	}
	focus, err := grade.FocusFile(m.Path)
	if err != nil {
		return grade.Focus{}, fmt.Errorf("focus: %w", err)
	}
	return focus, nil
}
