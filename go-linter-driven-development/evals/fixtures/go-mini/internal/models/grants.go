package models

import "slices"

type Permission string

const (
	PermRead  Permission = "read"
	PermWrite Permission = "write"
	PermAdmin Permission = "admin"
)

type Grants struct {
	perms []Permission
}

// NewGrants creates new Grants.
func NewGrants(perms ...Permission) Grants {
	return Grants{perms: perms}
}

// All returns all permissions.
func (g Grants) All() []Permission {
	return g.perms
}

// Has returns whether the grants have the permission.
func (g Grants) Has(p Permission) bool {
	return slices.Contains(g.perms, p)
}

type ReplicaCount int

func (c ReplicaCount) Int() int {
	return int(c)
}

type Name string

func (n Name) String() string {
	return string(n)
}
