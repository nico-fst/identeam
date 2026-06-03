package apns

import (
	"identeam/models"
	"math"
	"time"
)

type TimeSample struct {
	Time   time.Time
	Weight float64
}

func weightedCirculacMean(samples []TimeSample, referenceDay time.Time) (time.Time, bool) {
	if len(samples) == 0 { // guard empty data
		return time.Time{}, false
	}

	var sinSum float64 // weighted circle-coordinates
	var cosSum float64 // weighted circle-coordinates
	var weightSum float64

	for _, sample := range samples {
		if sample.Weight <= 0 {
			continue
		}

		// Time -> minutes since Mitternacht -> Angle on circle
		minutes := float64(sample.Time.Hour()*60 + sample.Time.Minute())
		angle := minutes / 1440.0 * 2.0 * math.Pi

		sinSum += math.Sin(angle) * sample.Weight
		cosSum += math.Cos(angle) * sample.Weight
		weightSum += sample.Weight
	}

	if weightSum == 0 { // guard if sum doesn't make sense
		return time.Time{}, false
	}

	// weighted Circle coordinates -> Angle
	meanAngle := math.Atan2(
		sinSum/weightSum,
		cosSum/weightSum,
	)

	// shall be positive angle
	if meanAngle < 0 {
		meanAngle += 2.0 * math.Pi
	}

	// Angle -> Minutes since midnight
	meanMinutes := int(math.Round(meanAngle/(2.0*math.Pi)*1440.0)) % 1440

	hour := meanMinutes / 60
	minute := meanMinutes % 60
	year, month, day := referenceDay.Date()

	return time.Date(year, month, day, hour, minute, 0, 0, referenceDay.Location()), true
}

func buildLast21DaysMeanSamples(idents []models.Ident, now time.Time) []TimeSample {
	samples := make([]TimeSample, 0, len(idents))

	for _, ident := range idents {
		daysAgo := now.Sub(ident.Time).Hours() / 24

		// only last 21d
		if daysAgo > 21 {
			continue
		}

		// newer <=> stronger
		weight := math.Exp(-daysAgo / 7.0)

		samples = append(samples, TimeSample{
			Time:   ident.Time,
			Weight: weight,
		})
	}

	return samples
}

func buildWeekdayMeanSamples(idents []models.Ident, now time.Time) []TimeSample {
	samples := make([]TimeSample, 0)

	currentWeekday := now.Weekday()

	for _, ident := range idents {
		// guard same weekday
		if ident.Time.Weekday() != currentWeekday {
			continue
		}

		daysAgo := now.Sub(ident.Time).Hours() / 24

		// guard only last 6 weeks
		if daysAgo > 42 {
			continue
		}

		weight := math.Exp(-daysAgo / 14.0)

		samples = append(samples, TimeSample{
			Time:   ident.Time,
			Weight: weight,
		})
	}

	return samples
}

func BuildIntelligentReminderTime(idents []models.Ident, now time.Time) (time.Time, bool) {
	last21DaysSamples := buildLast21DaysMeanSamples(idents, now)
	last21DaysMean, ok := weightedCirculacMean(last21DaysSamples, now)
	if !ok {
		return time.Time{}, false
	}

	weekdaySamples := buildWeekdayMeanSamples(idents, now)

	// not enough weekday data: last21Days
	if len(weekdaySamples) < 4 {
		return last21DaysMean, true
	}

	weekdayMean, ok := weightedCirculacMean(weekdaySamples, now)
	if !ok {
		return last21DaysMean, true
	}

	combinedSamples := []TimeSample{
		{
			Time:   last21DaysMean,
			Weight: 0.75,
		},
		{
			Time:   weekdayMean,
			Weight: 0.25,
		},
	}

	return weightedCirculacMean(combinedSamples, now)
}