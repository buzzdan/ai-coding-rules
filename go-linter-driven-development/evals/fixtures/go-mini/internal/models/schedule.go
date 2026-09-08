package models

import (
	"errors"
	"fmt"
	"slices"
	"time"
)

// Weekday is a weekday.
type Weekday = time.Weekday

// Schedule is a schedule.
type Schedule struct {
	days []Weekday
}

// NewSchedule creates a new Schedule.
func NewSchedule(days []Weekday) (Schedule, error) {
	if len(days) == 0 {
		return Schedule{}, errors.New("schedule: no days")
	}
	for _, d := range days {
		if d < time.Sunday || d > time.Saturday {
			return Schedule{}, fmt.Errorf("schedule: bad weekday %d", d)
		}
	}
	return Schedule{days: days}, nil
}

// Days returns the days.
func (s Schedule) Days() []Weekday {
	return s.days
}

// Includes returns whether the schedule includes the day.
func (s Schedule) Includes(d Weekday) bool {
	return slices.Contains(s.days, d)
}
