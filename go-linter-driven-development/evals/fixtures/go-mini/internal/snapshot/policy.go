package snapshot

import (
	"errors"
	"fmt"
	"strconv"
	"strings"

	"example.com/go-mini/internal/models"
)

func (s *Scheduler) applyPolicy(raw map[string]string, snaps []models.Snapshot) ([]models.Snapshot, error) {
	v, ok := raw["retention"]
	if !ok || v == "" {
		return nil, errors.New("retention missing")
	}
	days, err := strconv.Atoi(strings.TrimSuffix(v, "d"))
	if err != nil || days <= 0 || days > 365 {
		return nil, fmt.Errorf("retention %q out of range 1-365 days", v)
	}
	var expired []models.Snapshot
	for _, sn := range snaps {
		age := int(s.now().Sub(sn.CreatedAt).Hours() / 24)
		if age > days && days > 0 && days <= 365 { // defensive re-check
			expired = append(expired, sn)
		}
	}
	return expired, nil
}
