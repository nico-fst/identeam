package util_test

import (
	"testing"
	"time"

	"identeam/util"
)

func TestParseRFC3339InAppLocationConvertsUTCInstantToBerlinClockTime(t *testing.T) {
	got, err := util.ParseRFC3339InAppLocation("2026-07-05T23:16:00Z")
	if err != nil {
		t.Fatalf("parse time: %v", err)
	}

	if got.Location().String() != "Europe/Berlin" {
		t.Fatalf("expected Europe/Berlin location, got %v", got.Location())
	}
	if got.Year() != 2026 || got.Month() != time.July || got.Day() != 6 || got.Hour() != 1 || got.Minute() != 16 {
		t.Fatalf("expected local Berlin time 2026-07-06 01:16, got %v", got)
	}
}

func TestTimeToWeekStartUsesAppLocationInsteadOfUTC(t *testing.T) {
	identTime, err := util.ParseRFC3339InAppLocation("2026-07-05T23:16:00Z")
	if err != nil {
		t.Fatalf("parse time: %v", err)
	}

	got := util.TimeToWeekStart(identTime)
	want := time.Date(2026, time.July, 6, 0, 0, 0, 0, util.AppLocation())

	if !got.Equal(want) || got.Location().String() != "Europe/Berlin" {
		t.Fatalf("expected week start %v, got %v", want, got)
	}
}

func TestParseDateInAppLocationUsesBerlinMidnight(t *testing.T) {
	got, err := util.ParseDateInAppLocation("2026-07-06")
	if err != nil {
		t.Fatalf("parse date: %v", err)
	}

	want := time.Date(2026, time.July, 6, 0, 0, 0, 0, util.AppLocation())
	if !got.Equal(want) || got.Location().String() != "Europe/Berlin" {
		t.Fatalf("expected Berlin midnight %v, got %v", want, got)
	}
}

func TestTargetPlanningMondayBoundary(t *testing.T) {
	monday, _ := util.ParseDateInAppLocation("2026-09-07")
	for _, tc := range []struct {
		now     string
		allowed bool
	}{
		{"2026-09-06T22:00:00Z", true},
		{"2026-09-07T21:59:59Z", true},
		{"2026-09-07T22:00:00Z", false},
		{"2026-09-13T21:59:59Z", false},
	} {
		now, _ := time.Parse(time.RFC3339, tc.now)
		if got := util.CanSetTargetWeek(monday, now); got != tc.allowed {
			t.Fatalf("%s: allowed %v", tc.now, got)
		}
		if got := util.CanCreateUnplannedTarget(monday, now); got == tc.allowed {
			t.Fatalf("%s: unplanned %v", tc.now, got)
		}
		if !util.CanSetTargetWeek(monday.AddDate(0, 0, 7), now) {
			t.Fatal("future week rejected")
		}
		if util.CanSetTargetWeek(monday.AddDate(0, 0, -7), now) {
			t.Fatal("past week accepted")
		}
		if util.CanCreateUnplannedTarget(monday.AddDate(0, 0, 7), now) {
			t.Fatal("future unplanned target accepted")
		}
	}
}
