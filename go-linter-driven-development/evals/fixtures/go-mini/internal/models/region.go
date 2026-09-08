package models

import (
	"fmt"
	"slices"
)

// Region is the geographic region a device reports from. Values come from
// ParseRegion, so a Region in circulation is always one of the constants
// below.
type Region string

// The regions the fleet is deployed in.
const (
	RegionEU Region = "eu"
	RegionUS Region = "us"
	RegionAP Region = "ap"
)

// ParseRegion accepts the codes devices send in their region: tag.
func ParseRegion(raw string) (Region, error) {
	r := Region(raw)
	if !slices.Contains([]Region{RegionEU, RegionUS, RegionAP}, r) {
		return "", fmt.Errorf("region %q: want one of eu, us, ap", raw)
	}
	return r, nil
}

// Zone maps a region to the storage zone its snapshots are written to.
func (r Region) Zone() string {
	switch r {
	case RegionEU:
		return "eu-central-1"
	case RegionUS:
		return "us-east-1"
	case RegionAP:
		return "ap-southeast-1"
	}
	// Not reachable for values produced by ParseRegion; the compiler cannot
	// see that, so fall back to the code itself rather than an empty zone.
	return string(r)
}
