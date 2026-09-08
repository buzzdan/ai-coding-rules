package grade

import (
	"errors"
	"fmt"
	"strconv"
	"strings"
)

// ErrBadMatch is returned for a `match:` value that is not contains,
// not_contains or count:N.
var ErrBadMatch = errors.New("grade: match must be contains, not_contains or count:N")

type matchKind int

const (
	matchContains matchKind = iota
	matchNotContains
	matchCount
)

// Match is the `match:` field of a regex grader: how the number of hits is
// turned into pass/fail.
type Match struct {
	kind  matchKind
	count int
}

// ParseMatch parses "contains" (also the empty default), "not_contains" or
// "count:N" with N >= 0.
func ParseMatch(s string) (Match, error) {
	s = strings.TrimSpace(s)
	switch {
	case s == "" || s == "contains":
		return Match{kind: matchContains}, nil
	case s == "not_contains":
		return Match{kind: matchNotContains}, nil
	case strings.HasPrefix(s, "count:"):
		return parseCount(strings.TrimPrefix(s, "count:"))
	default:
		return Match{}, fmt.Errorf("%w: got %q", ErrBadMatch, s)
	}
}

func parseCount(raw string) (Match, error) {
	n, err := strconv.Atoi(strings.TrimSpace(raw))
	if err != nil || n < 0 {
		return Match{}, fmt.Errorf("%w: count:N needs N >= 0, got %q", ErrBadMatch, raw)
	}
	return Match{kind: matchCount, count: n}, nil
}

// Evaluate turns a hit count into a verdict and a human-readable detail.
func (m Match) Evaluate(hits int) (bool, string) {
	switch m.kind {
	case matchNotContains:
		return hits == 0, fmt.Sprintf("%d match(es); want 0", hits)
	case matchCount:
		return hits == m.count, fmt.Sprintf("%d match(es); want exactly %d", hits, m.count)
	default: // matchContains is the zero value
		return hits > 0, fmt.Sprintf("%d match(es); want at least 1", hits)
	}
}

// String renders the match the way it is written in a grader file.
func (m Match) String() string {
	switch m.kind {
	case matchNotContains:
		return "not_contains"
	case matchCount:
		return "count:" + strconv.Itoa(m.count)
	default: // matchContains is the zero value
		return "contains"
	}
}
