package models

import (
	"errors"
	"fmt"
)

const maxTenantLen = 32

// Tenant identifies the owner of a device fleet. A Tenant can only be
// obtained through ParseTenant, so every value in circulation is already
// non-empty, lowercase, and at most 32 characters long; nothing downstream
// needs to check it again.
type Tenant struct {
	id string
}

// ParseTenant validates a raw tenant identifier once, at the boundary.
func ParseTenant(raw string) (Tenant, error) {
	if raw == "" {
		return Tenant{}, errors.New("tenant: empty")
	}
	if len(raw) > maxTenantLen {
		return Tenant{}, fmt.Errorf("tenant %q: longer than %d characters", raw, maxTenantLen)
	}
	for _, r := range raw {
		if !isTenantRune(r) {
			return Tenant{}, fmt.Errorf("tenant %q: want lowercase letters, digits, or '-'", raw)
		}
	}
	return Tenant{id: raw}, nil
}

// ID returns the validated identifier for use in storage keys and logs.
func (t Tenant) ID() string {
	return t.id
}

func isTenantRune(r rune) bool {
	return (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-'
}
