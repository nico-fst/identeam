package test

import (
	"context"
	"fmt"
	"path/filepath"
	"testing"
	"time"

	"identeam/internal/db"
	"identeam/models"
	"identeam/util"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

type streakMemberWeek struct {
	targets int
	idents  int
}

func TestGetTeamWeekTeamStreak(t *testing.T) {
	// Index 0 is the current Berlin week, followed by consecutive older weeks.
	// Every fixture has positive targets, so these tests do not prescribe how
	// weeks without planning (including 0/0) should affect a streak.
	currentWeek := util.TimeToWeekStart(util.Now())
	tests := []struct {
		name  string
		weeks [][]streakMemberWeek
		want  uint
	}{
		{
			name:  "unfinished_current_week_preserves_two_completed_weeks",
			weeks: [][]streakMemberWeek{{{3, 1}}, {{2, 2}}, {{3, 4}}, {{2, 1}}},
			want:  2,
		},
		{
			name:  "current_week_without_idents_preserves_streak",
			weeks: [][]streakMemberWeek{{{3, 0}}, {{2, 2}}, {{2, 1}}},
			want:  1,
		},
		{
			name:  "completed_current_week_extends_streak",
			weeks: [][]streakMemberWeek{{{3, 3}}, {{2, 2}}, {{3, 4}}, {{2, 1}}},
			want:  3,
		},
		{
			name:  "overfulfilled_current_week_counts_only_once",
			weeks: [][]streakMemberWeek{{{2, 5}}, {{2, 2}}, {{2, 1}}},
			want:  2,
		},
		{
			name:  "unfinished_current_week_does_not_start_streak",
			weeks: [][]streakMemberWeek{{{3, 2}}, {{2, 1}}},
			want:  0,
		},
		{
			name:  "failed_previous_week_breaks_older_streak",
			weeks: [][]streakMemberWeek{{{3, 1}}, {{2, 1}}, {{2, 2}}, {{2, 3}}, {{2, 1}}},
			want:  0,
		},
		{
			name:  "completed_current_week_starts_new_streak_after_break",
			weeks: [][]streakMemberWeek{{{3, 3}}, {{2, 1}}, {{2, 2}}, {{2, 3}}, {{2, 1}}},
			want:  1,
		},
		{
			name:  "older_successes_after_gap_are_not_added",
			weeks: [][]streakMemberWeek{{{3, 3}}, {{2, 2}}, {{2, 1}}, {{2, 2}}, {{2, 3}}, {{2, 1}}},
			want:  2,
		},
		{
			name: "team_sum_counts_even_if_one_member_misses_target",
			weeks: [][]streakMemberWeek{
				{{3, 1}, {1, 3}},
				{{3, 0}, {1, 4}},
				{{3, 0}, {1, 1}},
			},
			want: 2,
		},
		{
			name: "one_successful_member_does_not_make_team_successful",
			weeks: [][]streakMemberWeek{
				{{3, 0}, {1, 1}},
				{{3, 0}, {1, 1}},
				{{3, 3}, {1, 1}},
				{{3, 0}, {1, 0}},
			},
			want: 0,
		},
		{
			name:  "surplus_idents_do_not_compensate_for_another_week",
			weeks: [][]streakMemberWeek{{{2, 6}}, {{2, 1}}, {{2, 2}}, {{2, 1}}},
			want:  1,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			services, team := newStreakFixture(t, currentWeek, tt.weeks)
			got, err := db.GetTeamWeek(context.Background(), services, team.Slug, currentWeek)
			if err != nil {
				t.Fatalf("GetTeamWeek: %v", err)
			}
			if got == nil {
				t.Fatal("GetTeamWeek returned nil response")
			}
			var wantTargets, wantIdents uint
			for _, member := range tt.weeks[0] {
				wantTargets += uint(member.targets)
				wantIdents += uint(member.idents)
			}
			if got.TargetSum != wantTargets || got.IdentSum != wantIdents {
				t.Fatalf("current week sums = %d/%d, want %d/%d (targets/idents)",
					got.TargetSum, got.IdentSum, wantTargets, wantIdents)
			}
			if got.TeamStreak != tt.want {
				t.Errorf("TeamStreak = %d, want %d", got.TeamStreak, tt.want)
			}
		})
	}
}

func newStreakFixture(t *testing.T, currentWeek time.Time, weeks [][]streakMemberWeek) (*db.Services, models.Team) {
	t.Helper()
	database, err := gorm.Open(sqlite.Open(filepath.Join(t.TempDir(), "streak.sqlite")), db.GormConfig())
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	sqlDB, err := database.DB()
	if err != nil {
		t.Fatalf("get sql DB: %v", err)
	}
	t.Cleanup(func() {
		if err := sqlDB.Close(); err != nil {
			t.Errorf("close sqlite: %v", err)
		}
	})
	if err := database.AutoMigrate(&models.User{}, &models.Team{}, &models.Target{},
		&models.TargetDay{}, &models.Ident{}, &models.Comment{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	create := func(value any) {
		t.Helper()
		if err := database.Create(value).Error; err != nil {
			t.Fatalf("create %T: %v", value, err)
		}
	}
	users := make([]models.User, len(weeks[0]))
	team := models.Team{Name: "Streak Team", Slug: "streak-team"}
	for i := range users {
		users[i] = models.User{
			UserID:   fmt.Sprintf("streak-user-%d", i),
			Email:    fmt.Sprintf("streak-%d@example.com", i),
			Username: fmt.Sprintf("streak-%d", i),
		}
		create(&users[i])
		team.Users = append(team.Users, &users[i])
	}
	create(&team)
	for offset, members := range weeks {
		week := currentWeek.AddDate(0, 0, -7*offset)
		for i, member := range members {
			target := models.Target{TimeStart: week, UserID: users[i].ID, TeamID: team.ID}
			for day := 0; day < member.targets; day++ {
				target.TargetDays = append(target.TargetDays, models.TargetDay{Date: week.AddDate(0, 0, day)})
			}
			for day := 0; day < member.idents; day++ {
				target.Idents = append(target.Idents, models.Ident{Time: week.AddDate(0, 0, day).Add(12 * time.Hour)})
			}
			create(&target)
		}
	}
	return db.NewServices(database), team
}
