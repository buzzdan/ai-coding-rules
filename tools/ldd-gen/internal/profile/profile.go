// Package profile reads a language binding's profile.yaml: the scalar values
// that core templates substitute, and the output paths the generator leaves
// alone because something else owns them at run time.
package profile

import (
	"bytes"
	"errors"
	"fmt"
	"path"
	"reflect"
	"strings"

	"gopkg.in/yaml.v3"
)

// Vars holds every scalar a core template may reference as {{.Name}}. Each
// field is required; an empty one means the binding forgot to say how the
// language spells that concept, so parsing fails instead of rendering blanks.
type Vars struct {
	Plugin         string `yaml:"plugin"`
	Lang           string `yaml:"lang"`
	CmdPrefix      string `yaml:"cmd_prefix"`
	SrcGlob        string `yaml:"src_glob"`
	TestGlob       string `yaml:"test_glob"`
	ProjectMarker  string `yaml:"project_marker"`
	Nolint         string `yaml:"nolint"`
	CommentPrefix  string `yaml:"comment_prefix"`
	DefaultTest    string `yaml:"default_test"`
	DefaultLint    string `yaml:"default_lint"`
	DefaultLintFix string `yaml:"default_lint_fix"`
}

// Profile is a parsed profile.yaml. Plugin doubles as the output directory
// name, so one binding always renders into exactly one plugin directory.
type Profile struct {
	Vars   `yaml:",inline"`
	Ignore []string `yaml:"ignore"`
}

// Parse decodes profile.yaml strictly: unknown keys and empty scalars are
// errors, so a typo in a key cannot silently render as an empty string.
func Parse(data []byte) (Profile, error) {
	var p Profile
	dec := yaml.NewDecoder(bytes.NewReader(data))
	dec.KnownFields(true)
	if err := dec.Decode(&p); err != nil {
		return Profile{}, fmt.Errorf("profile: %w", err)
	}
	if err := p.validate(); err != nil {
		return Profile{}, err
	}
	return p, nil
}

func (v Vars) validate() error {
	rv := reflect.ValueOf(v)
	rt := rv.Type()
	var missing []string
	for i := range rt.NumField() {
		if rv.Field(i).String() == "" {
			missing = append(missing, rt.Field(i).Tag.Get("yaml"))
		}
	}
	if len(missing) > 0 {
		return errors.New("profile: missing " + strings.Join(missing, ", "))
	}
	return nil
}

// Ignored reports whether an output path that the generator did not produce
// is tolerated. A pattern matches the path itself or any of its parent
// directories, so "evals/*" covers everything below evals/cases/.
func (p Profile) Ignored(rel string) bool {
	for _, pattern := range p.Ignore {
		if matchesPrefix(pattern, rel) {
			return true
		}
	}
	return false
}

func matchesPrefix(pattern, rel string) bool {
	for prefix := rel; prefix != "." && prefix != "/"; prefix = path.Dir(prefix) {
		if ok, _ := path.Match(pattern, prefix); ok {
			return true
		}
	}
	return false
}
