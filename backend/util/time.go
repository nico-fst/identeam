package util

import "time"

func TimeToWeekStart(t time.Time) time.Time {
	t = t.UTC()
	
	// Normalize to midnight first
	y, m, d := t.Date()
	loc := t.Location()
	midnight := time.Date(y, m, d, 0, 0, 0, 0, loc)

	weekday := int(midnight.Weekday())

	// Convert Go weekday (Sunday=0) to Monday-based offset
	daysSinceMonday := (weekday + 6) % 7

	return midnight.AddDate(0, 0, -daysSinceMonday)
}

func NextMon(from time.Time) time.Time {
	weekday := int(from.Weekday())

	daysUntilNextMonday := (8 - weekday) % 7
	if daysUntilNextMonday == 0 {
		daysUntilNextMonday = 7
	}

	return time.Date(
		from.Year(),
		from.Month(),
		from.Day(),
		0, 0, 0, 0,
		from.Location(),
	).AddDate(0, 0, daysUntilNextMonday)
}

func NextMonToSun(from time.Time) []time.Time {
	weekday := int(from.Weekday())

	// Sonntag=0, Montag=1, ...
	daysUntilNextMonday := (8 - weekday) % 7
	if daysUntilNextMonday == 0 {
		daysUntilNextMonday = 7
	}

	monday := time.Date(
		from.Year(),
		from.Month(),
		from.Day(),
		0, 0, 0, 0,
		from.Location(),
	).AddDate(0, 0, daysUntilNextMonday)

	days := make([]time.Time, 0, 7)
	for i := 0; i < 7; i++ {
		days = append(days, monday.AddDate(0, 0, i))
	}

	return days
}
