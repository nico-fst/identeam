package db

import (
	"strings"
	"testing"
	"time"

	"identeam/models"
	"identeam/util"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func newDryRunDB(t *testing.T) *gorm.DB {
	t.Helper()

	db, err := gorm.Open(sqlite.Open("file::memory:?cache=shared"), &gorm.Config{
		DryRun: true,
	})
	if err != nil {
		t.Fatalf("open dry-run db: %v", err)
	}

	return db
}

func TestGetUserWeeklyTargetByTimeUserTeamUsesJoinedTeamAlias(t *testing.T) {
	db := newDryRunDB(t)
	weekTime := time.Date(2026, 4, 18, 12, 0, 0, 0, time.UTC)

	sql := db.ToSQL(func(tx *gorm.DB) *gorm.DB {
		var target models.UserWeeklyTarget
		return tx.Model(&models.UserWeeklyTarget{}).
			Joins("Team").
			Where(
				"user_weekly_targets.time_start = ? AND user_weekly_targets.user_id = ? AND Team.slug = ?",
				util.TimeToWeekStart(weekTime),
				uint(2),
				"test",
			).
			First(&target)
	})

	if !strings.Contains(sql, `Team.slug`) {
		t.Fatalf("expected SQL to use joined Team alias, got %s", sql)
	}

	if strings.Contains(sql, `team.slug`) {
		t.Fatalf("expected SQL not to reference lowercase team alias, got %s", sql)
	}
}

func TestGetTeamsWeekTargetsUsesJoinedTeamAlias(t *testing.T) {
	db := newDryRunDB(t)
	weekTime := time.Date(2026, 4, 18, 12, 0, 0, 0, time.UTC)

	sql := db.ToSQL(func(tx *gorm.DB) *gorm.DB {
		var targets []models.UserWeeklyTarget
		return tx.Model(&models.UserWeeklyTarget{}).
			Joins("Team").
			Preload("User").
			Preload("Idents").
			Where(
				"Team.slug = ? AND user_weekly_targets.time_start = ?",
				"test",
				util.TimeToWeekStart(weekTime),
			).
			Find(&targets)
	})

	if !strings.Contains(sql, `Team.slug`) {
		t.Fatalf("expected SQL to use joined Team alias, got %s", sql)
	}

	if strings.Contains(sql, `team.slug`) {
		t.Fatalf("expected SQL not to reference lowercase team alias, got %s", sql)
	}
}
