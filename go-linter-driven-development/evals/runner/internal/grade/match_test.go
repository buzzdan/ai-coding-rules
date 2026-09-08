package grade_test

import (
	"errors"
	"testing"

	"example.com/ldd-eval/internal/grade"
)

func TestParseMatch_Success(t *testing.T) {
	t.Parallel()
	cases := []struct {
		input string
		want  string
	}{
		{input: "", want: "contains"},
		{input: "contains", want: "contains"},
		{input: " contains ", want: "contains"},
		{input: "not_contains", want: "not_contains"},
		{input: "count:0", want: "count:0"},
		{input: "count:3", want: "count:3"},
		{input: "count: 12", want: "count:12"},
	}
	for _, tc := range cases {
		t.Run(tc.input, func(t *testing.T) {
			t.Parallel()
			m, err := grade.ParseMatch(tc.input)
			if err != nil {
				t.Fatalf("ParseMatch(%q): %v", tc.input, err)
			}
			if m.String() != tc.want {
				t.Errorf("ParseMatch(%q).String() = %q, want %q", tc.input, m.String(), tc.want)
			}
		})
	}
}

func TestParseMatch_Error(t *testing.T) {
	t.Parallel()
	for _, input := range []string{"sometimes", "count:", "count:-1", "count:x", "contains:1", "COUNT:2"} {
		t.Run(input, func(t *testing.T) {
			t.Parallel()
			_, err := grade.ParseMatch(input)
			if !errors.Is(err, grade.ErrBadMatch) {
				t.Fatalf("ParseMatch(%q) error = %v, want ErrBadMatch", input, err)
			}
		})
	}
}

func TestMatch_Evaluate(t *testing.T) {
	t.Parallel()
	cases := []struct {
		match string
		hits  int
		want  bool
	}{
		{match: "contains", hits: 0, want: false},
		{match: "contains", hits: 1, want: true},
		{match: "contains", hits: 7, want: true},
		{match: "not_contains", hits: 0, want: true},
		{match: "not_contains", hits: 2, want: false},
		{match: "count:2", hits: 1, want: false},
		{match: "count:2", hits: 2, want: true},
		{match: "count:2", hits: 3, want: false},
		{match: "count:0", hits: 0, want: true},
	}
	for _, tc := range cases {
		t.Run(tc.match, func(t *testing.T) {
			t.Parallel()
			m, err := grade.ParseMatch(tc.match)
			if err != nil {
				t.Fatalf("ParseMatch: %v", err)
			}
			got, detail := m.Evaluate(tc.hits)
			if got != tc.want {
				t.Errorf("%s.Evaluate(%d) = %v (%s), want %v", tc.match, tc.hits, got, detail, tc.want)
			}
			if detail == "" {
				t.Error("Evaluate detail must not be empty")
			}
		})
	}
}

func TestMatch_ZeroValueIsContains(t *testing.T) {
	t.Parallel()
	var m grade.Match
	if m.String() != "contains" {
		t.Errorf("zero Match.String() = %q, want contains", m.String())
	}
	if ok, _ := m.Evaluate(1); !ok {
		t.Error("zero Match must behave as contains")
	}
}
