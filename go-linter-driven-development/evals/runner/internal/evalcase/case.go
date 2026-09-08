// Package evalcase loads eval cases from the `claude plugin eval` directory
// format: <case>/prompt.md (frontmatter + prompt body), <case>/graders/*.md
// and the optional <case>/case.yaml with the runner-specific extras.
package evalcase

import (
	"errors"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"slices"
	"sort"
	"strings"
	"time"

	"gopkg.in/yaml.v3"

	"example.com/ldd-eval/internal/frontmatter"
	"example.com/ldd-eval/internal/grade"
)

const (
	defaultRuns           = 3
	defaultMaxTurns       = 10
	defaultTimeoutSeconds = 300
	defaultScaffold       = "scaffold/default.sh"
)

// ErrEmptyPrompt is returned when prompt.md has no body.
var ErrEmptyPrompt = errors.New("evalcase: prompt body is empty")

// ErrNoGraders is returned when a case has neither graders/*.md nor a postcheck.
var ErrNoGraders = errors.New("evalcase: case has no graders")

// ErrBadValue is returned for a non-positive runs/max_turns/timeout_seconds.
var ErrBadValue = errors.New("evalcase: runs, max_turns and timeout_seconds must be > 0")

// Case is one loaded, validated eval case.
type Case struct {
	Name               string
	Dir                string
	Prompt             string
	Tags               []string
	Runs               int
	MaxTurns           int
	Timeout            time.Duration
	AllowedTools       []string
	Model              string
	AppendSystemPrompt string
	ScaffoldScript     string
	Postcheck          string
	Tier               string
	Notes              string
	Graders            []grade.Grader
}

type promptFront struct {
	Name               string   `yaml:"name"`
	Tags               []string `yaml:"tags"`
	Runs               *int     `yaml:"runs"`
	MaxTurns           *int     `yaml:"max_turns"`
	TimeoutSeconds     *int     `yaml:"timeout_seconds"`
	AllowedTools       []string `yaml:"allowed_tools"`
	Model              string   `yaml:"model"`
	AppendSystemPrompt string   `yaml:"append_system_prompt"`
}

type caseYAML struct {
	SchemaVersion string `yaml:"schema_version"`
	Context       struct {
		ScaffoldScript string `yaml:"scaffold_script"`
	} `yaml:"context"`
	Postcheck string `yaml:"postcheck"`
	Tier      string `yaml:"tier"`
	Notes     string `yaml:"notes"`
}

// Broken is a case directory that failed to load. Dir is the directory's
// basename — the only name a malformed case has, since its frontmatter may be
// what is broken.
type Broken struct {
	Dir string
	Err error
}

// Discover loads every <evalsDir>/*/prompt.md as a case, sorted by name. Any
// malformed case directory fails the whole discovery.
func Discover(evalsDir string) ([]Case, error) {
	cases, broken, err := DiscoverLenient(evalsDir)
	if err != nil {
		return nil, err
	}
	if len(broken) > 0 {
		return nil, broken[0].Err
	}
	return cases, nil
}

// DiscoverLenient loads every case it can and reports the directories it
// cannot, so one half-written case never hides the rest of the suite from a
// filtered run. The caller decides whether a broken directory matters.
func DiscoverLenient(evalsDir string) ([]Case, []Broken, error) {
	prompts, err := filepath.Glob(filepath.Join(evalsDir, "*", "prompt.md"))
	if err != nil {
		return nil, nil, fmt.Errorf("evalcase: glob %s: %w", evalsDir, err)
	}
	cases := make([]Case, 0, len(prompts))
	var broken []Broken
	for _, p := range prompts {
		dir := filepath.Dir(p)
		c, lerr := Load(dir)
		if lerr != nil {
			broken = append(broken, Broken{Dir: filepath.Base(dir), Err: lerr})
			continue
		}
		cases = append(cases, c)
	}
	sort.Slice(cases, func(i, j int) bool { return cases[i].Name < cases[j].Name })
	return cases, broken, nil
}

// Load reads one case directory. The evals dir (for the default scaffold) is
// the case dir's parent.
func Load(caseDir string) (Case, error) {
	caseDir, err := filepath.Abs(caseDir)
	if err != nil {
		return Case{}, fmt.Errorf("evalcase: abs %s: %w", caseDir, err)
	}
	c, err := loadPrompt(caseDir)
	if err != nil {
		return Case{}, err
	}
	if err := c.applyCaseYAML(); err != nil {
		return Case{}, err
	}
	if err := c.loadGraders(); err != nil {
		return Case{}, err
	}
	return c, nil
}

func loadPrompt(caseDir string) (Case, error) {
	data, err := os.ReadFile(filepath.Join(caseDir, "prompt.md"))
	if err != nil {
		return Case{}, fmt.Errorf("evalcase: %w", err)
	}
	doc, err := frontmatter.Parse(data)
	if err != nil {
		return Case{}, fmt.Errorf("evalcase: %s/prompt.md: %w", caseDir, err)
	}
	var fm promptFront
	if err := doc.Decode(&fm); err != nil {
		return Case{}, fmt.Errorf("evalcase: %s/prompt.md: %w", caseDir, err)
	}
	if doc.Body() == "" {
		return Case{}, fmt.Errorf("%w: %s/prompt.md", ErrEmptyPrompt, caseDir)
	}
	return fm.toCase(caseDir, doc.Body())
}

func (fm promptFront) toCase(caseDir, body string) (Case, error) {
	c := Case{
		Name:               strings.TrimSpace(fm.Name),
		Dir:                caseDir,
		Prompt:             body,
		Tags:               fm.Tags,
		Runs:               orDefault(fm.Runs, defaultRuns),
		MaxTurns:           orDefault(fm.MaxTurns, defaultMaxTurns),
		Timeout:            time.Duration(orDefault(fm.TimeoutSeconds, defaultTimeoutSeconds)) * time.Second,
		AllowedTools:       fm.AllowedTools,
		Model:              strings.TrimSpace(fm.Model),
		AppendSystemPrompt: fm.AppendSystemPrompt,
		ScaffoldScript:     filepath.Join(filepath.Dir(caseDir), defaultScaffold),
	}
	if c.Name == "" {
		c.Name = filepath.Base(caseDir)
	}
	if c.Runs <= 0 || c.MaxTurns <= 0 || c.Timeout <= 0 {
		return Case{}, fmt.Errorf("%w: case %s", ErrBadValue, c.Name)
	}
	return c, nil
}

func orDefault(v *int, def int) int {
	if v == nil {
		return def
	}
	return *v
}

func (c *Case) applyCaseYAML() error {
	data, err := os.ReadFile(filepath.Join(c.Dir, "case.yaml"))
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("evalcase: %w", err)
	}
	var cy caseYAML
	if err := yaml.Unmarshal(data, &cy); err != nil {
		return fmt.Errorf("evalcase: %s/case.yaml: %w", c.Dir, err)
	}
	if cy.Context.ScaffoldScript != "" {
		c.ScaffoldScript = c.resolve(cy.Context.ScaffoldScript)
	}
	if cy.Postcheck != "" {
		c.Postcheck = c.resolve(cy.Postcheck)
	}
	c.Tier, c.Notes = strings.TrimSpace(cy.Tier), strings.TrimSpace(cy.Notes)
	return nil
}

// resolve makes a case.yaml path absolute relative to the case dir.
func (c Case) resolve(p string) string {
	if filepath.IsAbs(p) {
		return filepath.Clean(p)
	}
	return filepath.Clean(filepath.Join(c.Dir, p))
}

func (c *Case) loadGraders() error {
	if _, err := os.Stat(c.ScaffoldScript); err != nil {
		return fmt.Errorf("evalcase: case %s scaffold script: %w", c.Name, err)
	}
	graders, err := loadGraderFiles(filepath.Join(c.Dir, "graders"))
	if err != nil {
		return fmt.Errorf("evalcase: case %s: %w", c.Name, err)
	}
	if c.Postcheck != "" {
		pc, perr := grade.NewPostcheck(c.Postcheck)
		if perr != nil {
			return fmt.Errorf("evalcase: case %s: %w", c.Name, perr)
		}
		graders = append(graders, pc)
	}
	if len(graders) == 0 {
		return fmt.Errorf("%w: %s", ErrNoGraders, c.Name)
	}
	c.Graders = graders
	return nil
}

// HasTag reports whether the case carries the tag.
func (c Case) HasTag(tag string) bool {
	return slices.Contains(c.Tags, tag)
}

// MatchesGlob reports whether the case name matches a path.Match glob.
func (c Case) MatchesGlob(glob string) (bool, error) {
	ok, err := path.Match(glob, c.Name)
	if err != nil {
		return false, fmt.Errorf("evalcase: bad case glob %q: %w", glob, err)
	}
	return ok, nil
}
