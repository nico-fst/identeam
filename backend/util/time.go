package util

import (
	"identeam/internal/appclock"
	"identeam/models"
	"strings"
	"time"
)

func AppLocation() *time.Location {
	return appclock.Location()
}

func Now() time.Time {
	return appclock.Now()
}

func TimeInAppLocation(t time.Time) time.Time {
	return appclock.InLocation(t)
}

func ParseRFC3339InAppLocation(value string) (time.Time, error) {
	t, err := time.Parse(time.RFC3339, value)
	if err != nil {
		return time.Time{}, err
	}
	return TimeInAppLocation(t), nil
}

func ParseDateInAppLocation(value string) (time.Time, error) {
	return time.ParseInLocation("2006-01-02", value, AppLocation())
}

func TimeToWeekStart(t time.Time) time.Time {
	t = TimeInAppLocation(t)

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

func StringsToDates(dates []string) ([]time.Time, error) {
	parsedDates := make([]time.Time, 0, len(dates))

	for _, dateString := range dates {
		date, err := ParseDateInAppLocation(dateString)
		if err != nil {
			return nil, err
		}

		parsedDates = append(parsedDates, date)
	}

	return parsedDates, nil
}

func TargetDaysToDates(targetdays []models.TargetDay) []time.Time {
	dates := make([]time.Time, 0, len(targetdays))

	for _, targetDay := range targetdays {
		dates = append(dates, targetDay.Date)
	}

	return dates
}

func DatesToWeekdays(dates []time.Time, joinOperator string) string {
	weekdays := make([]string, 0, len(dates))

	for _, date := range dates {
		weekdays = append(weekdays, date.Format("Mon"))
	}

	return strings.Join(weekdays, joinOperator)
}
