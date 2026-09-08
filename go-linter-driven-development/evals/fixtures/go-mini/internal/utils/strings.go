// Package utils holds string and time helpers.
package utils //nolint:revive // TODO

import (
	"strings"
	"unicode"
)

// Truncate truncates s to at most n runes.
func Truncate(s string, n int) string {
	if n <= 0 {
		return ""
	}
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return string(r[:n])
}

// Slugify lowercases s and replaces runs of non-alphanumerics with a dash.
func Slugify(s string) string {
	var b strings.Builder
	dash := false
	for _, c := range strings.ToLower(s) {
		if unicode.IsLetter(c) || unicode.IsDigit(c) {
			b.WriteRune(c)
			dash = false
			continue
		}
		if !dash && b.Len() > 0 {
			b.WriteByte('-')
			dash = true
		}
	}
	return strings.TrimSuffix(b.String(), "-")
}

// Contains reports whether xs contains x.
func Contains(xs []string, x string) bool {
	for _, v := range xs {
		if v == x {
			return true
		}
	}
	return false
}
