package util

import "time"

func TimeToWeekStart(t time.Time) time.Time {
	// Normalize to midnight first
	y, m, d := t.Date()
	loc := t.Location()
	midnight := time.Date(y, m, d, 0, 0, 0, 0, loc)

	weekday := int(midnight.Weekday())

	// Convert Go weekday (Sunday=0) to Monday-based offset
	daysSinceMonday := (weekday + 6) % 7

	return midnight.AddDate(0, 0, -daysSinceMonday)
}
