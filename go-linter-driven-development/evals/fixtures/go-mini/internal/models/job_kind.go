package models

const (
	JobKindSnapshot = "snapshot"
	JobKindSync     = "sync"
)

type Priority int

const (
	Low Priority = iota
	Medium
	High
)
