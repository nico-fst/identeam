package apns

import (
	"identeam/models"
	"testing"
	"time"
)

func TestBuildIntelligentReminderTimeUsesHistoryAgeFromNow(t *testing.T) {
	location := time.FixedZone("CEST", 2*60*60)
	now := time.Date(2026, time.September, 4, 12, 0, 0, 0, location)
	reminderDay := time.Date(2026, time.September, 12, 0, 0, 0, 0, location)
	idents := []models.Ident{
		{Time: now.AddDate(0, 0, -20).Add(7 * time.Hour)},
	}

	reminder, ok := BuildIntelligentReminderTime(idents, reminderDay, now)
	if !ok {
		t.Fatal("expected an ident from the last 21 days to produce a reminder")
	}
	if reminder.Year() != reminderDay.Year() ||
		reminder.Month() != reminderDay.Month() ||
		reminder.Day() != reminderDay.Day() {
		t.Fatalf("expected reminder on %v, got %v", reminderDay, reminder)
	}
	if reminder.Hour() != 19 || reminder.Minute() != 0 {
		t.Fatalf("expected reminder time 19:00, got %02d:%02d", reminder.Hour(), reminder.Minute())
	}
}

func TestBuildIntelligentReminderTimeRejectsHistoryOlderThan21Days(t *testing.T) {
	location := time.FixedZone("CEST", 2*60*60)
	now := time.Date(2026, time.September, 4, 12, 0, 0, 0, location)
	reminderDay := time.Date(2026, time.September, 7, 0, 0, 0, 0, location)
	idents := []models.Ident{
		{Time: now.AddDate(0, 0, -22)},
	}

	if _, ok := BuildIntelligentReminderTime(idents, reminderDay, now); ok {
		t.Fatal("expected history older than 21 days to require the client default")
	}
}
