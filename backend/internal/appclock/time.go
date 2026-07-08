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
