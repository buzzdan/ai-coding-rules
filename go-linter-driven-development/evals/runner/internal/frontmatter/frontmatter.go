// Package frontmatter splits a markdown document into its YAML frontmatter and
// body, mirroring the file layout `claude plugin eval` uses for prompt.md and
// graders/*.md.
package frontmatter

import (
	"bytes"
	"errors"
	"fmt"
	"strings"

	"gopkg.in/yaml.v3"
)

// ErrMissing is returned when a document does not start with a `---` fence.
var ErrMissing = errors.New("frontmatter: document does not start with ---")

// ErrUnterminated is returned when the opening fence has no closing `---`.
var ErrUnterminated = errors.New("frontmatter: opening --- has no closing ---")

// Document is a parsed markdown file: the raw YAML between the fences and the
// trimmed body after the closing fence.
type Document struct {
	front []byte
	body  string
}

// Parse splits data into frontmatter and body. The document must begin with a
// `---` line; the body is everything after the closing `---` line, trimmed.
func Parse(data []byte) (Document, error) {
	text := strings.ReplaceAll(strings.TrimPrefix(string(data), "\uFEFF"), "\r\n", "\n")
	if !strings.HasPrefix(text, "---\n") {
		return Document{}, ErrMissing
	}
	rest := text[len("---\n"):]
	end, bodyStart, ok := closingFence(rest)
	if !ok {
		return Document{}, ErrUnterminated
	}
	// Keep the newline that terminates the last frontmatter line so YAML block
	// scalars (`key: |`) keep their trailing newline as they would in a file.
	front := rest[:end]
	if end > 0 {
		front += "\n"
	}
	return Document{front: []byte(front), body: strings.TrimSpace(rest[bodyStart:])}, nil
}

// closingFence locates the first line that is exactly `---` and returns the
// offset where the frontmatter ends (exclusive of its newline) and where the
// body begins.
func closingFence(rest string) (end, bodyStart int, ok bool) {
	if strings.HasPrefix(rest, "---\n") || rest == "---" {
		return 0, min(len(rest), len("---\n")), true
	}
	idx := strings.Index(rest, "\n---")
	for idx >= 0 {
		after := idx + len("\n---")
		if after == len(rest) || rest[after] == '\n' {
			return idx, min(len(rest), after+1), true
		}
		next := strings.Index(rest[after:], "\n---")
		if next < 0 {
			break
		}
		idx = after + next
	}
	return 0, 0, false
}

// Front returns the raw YAML frontmatter.
func (d Document) Front() []byte { return d.front }

// Body returns the markdown body after the closing fence, trimmed of
// surrounding whitespace.
func (d Document) Body() string { return d.body }

// Decode unmarshals the YAML frontmatter into v, rejecting unknown fields so
// that a misspelled key fails loudly instead of silently taking a default.
func (d Document) Decode(v any) error {
	if len(bytes.TrimSpace(d.front)) == 0 {
		return nil
	}
	dec := yaml.NewDecoder(bytes.NewReader(d.front))
	dec.KnownFields(true)
	if err := dec.Decode(v); err != nil {
		return fmt.Errorf("frontmatter: decode yaml: %w", err)
	}
	return nil
}
