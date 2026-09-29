package test

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"identeam/models"
)

func TestTeamWeekResponseWeekStart(t *testing.T) {
	for _, tc := range []struct {
		name string
		date string
		want string
	}{
		{"midweek", "2026-09-30T12:00:00Z", "2026-09-28"},
		{"monday_in_berlin", "2026-09-27T22:30:00Z", "2026-09-28"},
		{"summer_time_change", "2026-03-29T12:00:00Z", "2026-03-23"},
		{"winter_time_change", "2026-10-25T12:00:00Z", "2026-10-19"},
		{"year_boundary", "2027-01-01T12:00:00Z", "2026-12-28"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			date, err := time.Parse(time.RFC3339, tc.date)
			if err != nil {
				t.Fatal(err)
			}
			got := models.NewTeamWeekResponse(context.Background(), nil, "team", nil, date)
			if got.WeekStart.Format("2006-01-02") != tc.want {
				t.Fatalf("WeekStart = %q, want %q", got.WeekStart, tc.want)
			}
			encoded, err := json.Marshal(got)
			if err != nil {
				t.Fatal(err)
			}
			var decoded models.TeamWeekResponse
			if err := json.Unmarshal(encoded, &decoded); err != nil {
				t.Fatal(err)
			}
			if !decoded.WeekStart.Equal(got.WeekStart) {
				t.Fatal("weekStart changed in JSON round trip")
			}
		})
	}
}
