package frontmatter_test

import (
	"errors"
	"testing"

	"example.com/ldd-eval/internal/frontmatter"
)

type sample struct {
	Name string   `yaml:"name"`
	Tags []string `yaml:"tags"`
}

func TestParse_Success(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name      string
		input     string
		wantFront string
		wantBody  string
	}{
		{
			name:      "front and body",
			input:     "---\nname: x\ntags: [a, b]\n---\n/go-ldd-review\n",
			wantFront: "name: x\ntags: [a, b]\n",
			wantBody:  "/go-ldd-review",
		},
		{
			name:      "crlf line endings",
			input:     "---\r\nname: x\r\n---\r\nbody\r\n",
			wantFront: "name: x\n",
			wantBody:  "body",
		},
		{
			name:      "bom prefix",
			input:     "\uFEFF---\nname: x\n---\nbody",
			wantFront: "name: x\n",
			wantBody:  "body",
		},
		{
			name:      "empty front",
			input:     "---\n---\nbody",
			wantFront: "",
			wantBody:  "body",
		},
		{
			name:      "no body",
			input:     "---\nname: x\n---",
			wantFront: "name: x\n",
			wantBody:  "",
		},
		{
			name:      "dashes inside yaml value are not a fence",
			input:     "---\npattern: 'a---b'\n---\nbody",
			wantFront: "pattern: 'a---b'\n",
			wantBody:  "body",
		},
		{
			name:      "multi-line body keeps inner content",
			input:     "---\nname: x\n---\n\nline one\n\nline two\n",
			wantFront: "name: x\n",
			wantBody:  "line one\n\nline two",
		},
		{
			name:      "false fence is skipped until the real one",
			input:     "---\na: 1\n---x\nb: 2\n---\nbody",
			wantFront: "a: 1\n---x\nb: 2\n",
			wantBody:  "body",
		},
		{
			name:      "block scalar keeps its trailing newline",
			input:     "---\nprompt: |\n  Be brief.\n---\nbody",
			wantFront: "prompt: |\n  Be brief.\n",
			wantBody:  "body",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			doc, err := frontmatter.Parse([]byte(tc.input))
			if err != nil {
				t.Fatalf("Parse: %v", err)
			}
			if got := string(doc.Front()); got != tc.wantFront {
				t.Errorf("Front() = %q, want %q", got, tc.wantFront)
			}
			if got := doc.Body(); got != tc.wantBody {
				t.Errorf("Body() = %q, want %q", got, tc.wantBody)
			}
		})
	}
}

func TestParse_Error(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name    string
		input   string
		wantErr error
	}{
		{name: "no fence", input: "name: x\n---\nbody", wantErr: frontmatter.ErrMissing},
		{name: "empty", input: "", wantErr: frontmatter.ErrMissing},
		{name: "unterminated", input: "---\nname: x\nbody", wantErr: frontmatter.ErrUnterminated},
		{name: "fence with trailing text", input: "---\nname: x\n---x\nbody", wantErr: frontmatter.ErrUnterminated},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, err := frontmatter.Parse([]byte(tc.input))
			if !errors.Is(err, tc.wantErr) {
				t.Fatalf("Parse error = %v, want %v", err, tc.wantErr)
			}
		})
	}
}

func TestDocument_Decode_Success(t *testing.T) {
	t.Parallel()
	doc, err := frontmatter.Parse([]byte("---\nname: x\ntags: [a, b]\n---\nbody"))
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	var got sample
	if err := doc.Decode(&got); err != nil {
		t.Fatalf("Decode: %v", err)
	}
	if got.Name != "x" || len(got.Tags) != 2 || got.Tags[1] != "b" {
		t.Errorf("Decode = %+v, want name x tags [a b]", got)
	}
}

func TestDocument_Decode_EmptyFrontLeavesZeroValue(t *testing.T) {
	t.Parallel()
	doc, err := frontmatter.Parse([]byte("---\n---\nbody"))
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	var got sample
	if err := doc.Decode(&got); err != nil {
		t.Fatalf("Decode: %v", err)
	}
	if got.Name != "" || got.Tags != nil {
		t.Errorf("Decode = %+v, want zero value", got)
	}
}

func TestDocument_Decode_Error(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name  string
		input string
	}{
		{name: "unknown field", input: "---\nunknown_key: x\n---\nbody"},
		{name: "wrong type", input: "---\ntags: notalist\n---\nbody"},
		{name: "invalid yaml", input: "---\nname: [unclosed\n---\nbody"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			doc, err := frontmatter.Parse([]byte(tc.input))
			if err != nil {
				t.Fatalf("Parse: %v", err)
			}
			var got sample
			if err := doc.Decode(&got); err == nil {
				t.Fatal("Decode: want error, got nil")
			}
		})
	}
}
