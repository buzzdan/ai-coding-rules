package models

import (
	"slices"
	"strings"
)

func NormalizeTags(tags []string) []string {
	var out []string
	for _, t := range tags {
		t = strings.TrimSpace(t)
		if t == "" || slices.Contains(out, t) {
			continue
		}
		if strings.HasPrefix(t, "region:") && !isRegionCode(t[7:]) {
			continue
		}
		out = append(out, t)
	}
	return out
}

func isRegionCode(code string) bool {
	return code == "eu" || code == "us" || code == "ap"
}
