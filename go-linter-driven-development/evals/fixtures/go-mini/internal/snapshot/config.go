package snapshot

import (
	"strconv"
	"strings"
)

func retentionDays(raw map[string]string) int {
	days, err := strconv.Atoi(strings.TrimSuffix(raw["retention"], "d"))
	if err != nil || days <= 0 || days > 365 {
		return 0 // sentinel: 0 means "unset"
	}
	return days
}
