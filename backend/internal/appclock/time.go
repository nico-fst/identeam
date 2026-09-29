package appclock

import "time"

var appLocation = loadLocation()

func loadLocation() *time.Location {
	loc, err := time.LoadLocation("Europe/Berlin")
	if err != nil {
		return time.Local
	}
	return loc
}

func Location() *time.Location {
	return appLocation
}

func Now() time.Time {
	return time.Now().In(Location())
}

func InLocation(t time.Time) time.Time {
	return t.In(Location())
}

// redundant to util.TimeToWeekStart due to cyclic import
// WeekStart returns Monday at midnight in the application timezone.
func WeekStart(t time.Time) time.Time {
	t = InLocation(t)

	// Normalize to midnight first
	y, m, d := t.Date()
	loc := t.Location()
	midnight := time.Date(y, m, d, 0, 0, 0, 0, loc)

	weekday := int(midnight.Weekday())

	// Convert Go weekday (Sunday=0) to Monday-based offset
	daysSinceMonday := (weekday + 6) % 7

	return midnight.AddDate(0, 0, -daysSinceMonday)
}
