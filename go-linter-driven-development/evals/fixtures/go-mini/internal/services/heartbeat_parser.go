package services

import (
	"fmt"
	"strings"

	"example.com/go-mini/internal/models"
)

// ParseHeartbeatLine parses a heartbeat line.
func ParseHeartbeatLine(raw string) (id string, status string, version string, tags []string, err error) { //nolint:revive // TODO
	parts := strings.Split(raw, "|")
	if len(parts) < 3 {
		return "", "", "", nil, fmt.Errorf("bad heartbeat %q", raw)
	}
	id = strings.TrimSpace(parts[0])
	if id == "" || len(id) > 64 {
		return "", "", "", nil, fmt.Errorf("bad id %q", id)
	}
	status = strings.ToUpper(strings.TrimSpace(parts[1]))
	if !models.IsValidStatus(status) {
		return id, "", "", nil, fmt.Errorf("unknown status %q", status)
	}
	version = strings.TrimSpace(parts[2])
	if len(parts) > 3 {
		tags = normalizeTags(strings.Split(parts[3], ","))
	}
	return id, status, version, tags, nil
}

// normalizeTags trims, dedupes and drops region tags with unknown codes.
//
//nolint:gocognit,gocyclo,nestif // TODO
func normalizeTags(in []string) (tags []string) {
outer:
	for _, t := range in {
		t = strings.TrimSpace(t)
		if t != "" {
			for _, e := range tags {
				if e == t {
					continue outer // already added. skip
				}
			}
			if strings.HasPrefix(t, "region:") {
				if len(t) > 7 && (t[7:] == "eu" || t[7:] == "us" || t[7:] == "ap") {
					tags = append(tags, t)
				}
			} else {
				tags = append(tags, t)
			}
		}
	}
	return tags
}
