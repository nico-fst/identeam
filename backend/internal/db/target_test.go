package db

import (
	"context"
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
			Preload("Idents.Comments.User").
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

func TestGetTeamsWeekTargetsPreloadsIdentCommentsAndUsers(t *testing.T) {
	sqliteDB, err := gorm.Open(sqlite.Open("file::memory:?cache=shared"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open sqlite db: %v", err)
	}

	err = sqliteDB.AutoMigrate(
		&models.User{},
		&models.Team{},
		&models.UserWeeklyTarget{},
		&models.Ident{},
		&models.Comment{},
	)
	if err != nil {
		t.Fatalf("automigrate: %v", err)
	}

	owner := models.User{
		UserID:       "owner-auth-id",
		Email:        "owner@example.com",
		AuthProvider: "password",
		FullName:     "Target Owner",
		Username:     "owner",
	}
	commenter := models.User{
		UserID:       "commenter-auth-id",
		Email:        "commenter@example.com",
		AuthProvider: "password",
		FullName:     "Commenter User",
		Username:     "commenter",
	}
	team := models.Team{
		Name: "Comment Team",
		Slug: "comment-team",
	}
	if err := sqliteDB.Create(&owner).Error; err != nil {
		t.Fatalf("create owner: %v", err)
	}
	if err := sqliteDB.Create(&commenter).Error; err != nil {
		t.Fatalf("create commenter: %v", err)
	}
	if err := sqliteDB.Create(&team).Error; err != nil {
		t.Fatalf("create team: %v", err)
	}

	weekTime := time.Date(2026, 6, 30, 13, 0, 0, 0, time.UTC)
	target := models.UserWeeklyTarget{
		TimeStart:   util.TimeToWeekStart(weekTime),
		UserID:      owner.ID,
		TeamID:      team.ID,
		TargetCount: 3,
	}
	if err := sqliteDB.Create(&target).Error; err != nil {
		t.Fatalf("create target: %v", err)
	}

	ident := models.Ident{
		Time:               weekTime,
		UserText:           "shipped a useful thing",
		UserWeeklyTargetID: target.ID,
	}
	if err := sqliteDB.Create(&ident).Error; err != nil {
		t.Fatalf("create ident: %v", err)
	}

	comment := models.Comment{
		Text:    "nice work",
		IdentID: ident.ID,
		UserID:  commenter.ID,
	}
	if err := sqliteDB.Create(&comment).Error; err != nil {
		t.Fatalf("create comment: %v", err)
	}

	targets, err := GetTeamsWeekTargets(context.Background(), NewServices(sqliteDB), team.Slug, weekTime)
	if err != nil {
		t.Fatalf("get team week targets: %v", err)
	}
	if len(targets) != 1 {
		t.Fatalf("expected one target, got %d", len(targets))
	}
	if targets[0].User.ID != owner.ID {
		t.Fatalf("expected target user id %d, got %d", owner.ID, targets[0].User.ID)
	}
	if len(targets[0].Idents) != 1 {
		t.Fatalf("expected one ident, got %d", len(targets[0].Idents))
	}
	comments := targets[0].Idents[0].Comments
	if len(comments) != 1 {
		t.Fatalf("expected one comment, got %d", len(comments))
	}
	if comments[0].Text != comment.Text {
		t.Fatalf("expected comment text %q, got %q", comment.Text, comments[0].Text)
	}
	if comments[0].User.ID != commenter.ID {
		t.Fatalf("expected comment user id %d, got %d", commenter.ID, comments[0].User.ID)
	}
}
