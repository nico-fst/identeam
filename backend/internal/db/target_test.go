package db

import (
	"context"
	"path/filepath"
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

func TestGetTargetByTimeUserTeamUsesJoinedTeamAlias(t *testing.T) {
	db := newDryRunDB(t)
	weekTime := time.Date(2026, 4, 18, 12, 0, 0, 0, time.UTC)

	sql := db.ToSQL(func(tx *gorm.DB) *gorm.DB {
		var target models.Target
		return tx.Model(&models.Target{}).
			Joins("Team").
			Where(
				"targets.time_start = ? AND targets.user_id = ? AND Team.slug = ?",
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
		var targets []models.Target
		return tx.Model(&models.Target{}).
			Joins("Team").
			Preload("User").
			Preload("Idents").
			Preload("Idents.Comments.User").
			Where(
				"Team.slug = ? AND targets.time_start = ?",
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
	sqliteDB, err := gorm.Open(sqlite.Open(filepath.Join(t.TempDir(), "legacy.sqlite")), &gorm.Config{})
	if err != nil {
		t.Fatalf("open sqlite db: %v", err)
	}

	err = sqliteDB.AutoMigrate(
		&models.User{},
		&models.Team{},
		&models.Target{},
		&models.TargetDay{},
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
		Nickname:     "Target Owner",
		Username:     "owner",
	}
	commenter := models.User{
		UserID:       "commenter-auth-id",
		Email:        "commenter@example.com",
		AuthProvider: "password",
		Nickname:     "Commenter User",
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
	target := models.Target{
		TimeStart: util.TimeToWeekStart(weekTime),
		UserID:    owner.ID,
		TeamID:    team.ID,
		TargetDays: []models.TargetDay{
			{Date: util.TimeToWeekStart(weekTime)},
		},
	}
	if err := sqliteDB.Create(&target).Error; err != nil {
		t.Fatalf("create target: %v", err)
	}

	ident := models.Ident{
		Time:     weekTime,
		UserText: "shipped a useful thing",
		TargetID: target.ID,
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
	if len(targets[0].TargetDays) != 1 {
		t.Fatalf("expected one target day, got %d", len(targets[0].TargetDays))
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

func TestReplaceTargetDaysCreatesReplacesAndRollsBack(t *testing.T) {
	sqliteDB, err := gorm.Open(sqlite.Open(filepath.Join(t.TempDir(), "replace-target-days.sqlite")), &gorm.Config{})
	if err != nil {
		t.Fatalf("open sqlite db: %v", err)
	}
	if err := sqliteDB.AutoMigrate(
		&models.User{},
		&models.Team{},
		&models.Target{},
		&models.TargetDay{},
	); err != nil {
		t.Fatalf("automigrate: %v", err)
	}

	user := models.User{UserID: "target-days-user", Email: "target-days@example.com", Username: "target-days"}
	team := models.Team{Name: "Target Days", Slug: "target-days"}
	if err := sqliteDB.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}
	if err := sqliteDB.Create(&team).Error; err != nil {
		t.Fatalf("create team: %v", err)
	}

	weekDate := time.Date(2026, 4, 8, 12, 0, 0, 0, util.AppLocation())
	weekStart := util.TimeToWeekStart(weekDate)
	targetInput := models.Target{TimeStart: weekDate, UserID: user.ID, TeamID: team.ID}

	created, err := ReplaceTargetDays(
		context.Background(),
		NewServices(sqliteDB),
		targetInput,
		[]time.Time{weekStart.AddDate(0, 0, 4), weekStart},
	)
	if err != nil {
		t.Fatalf("create target days: %v", err)
	}
	if created.ID == 0 {
		t.Fatal("expected database-generated target ID")
	}
	if !created.TimeStart.Equal(weekStart) {
		t.Fatalf("expected normalized week start %v, got %v", weekStart, created.TimeStart)
	}
	if len(created.TargetDays) != 2 {
		t.Fatalf("expected two target days, got %d", len(created.TargetDays))
	}
	if !created.TargetDays[0].Date.Equal(weekStart) || !created.TargetDays[1].Date.Equal(weekStart.AddDate(0, 0, 4)) {
		t.Fatalf("expected sorted target days, got %#v", created.TargetDays)
	}

	replacementDate := weekStart.AddDate(0, 0, 2)
	replaced, err := ReplaceTargetDays(
		context.Background(),
		NewServices(sqliteDB),
		targetInput,
		[]time.Time{replacementDate},
	)
	if err != nil {
		t.Fatalf("replace target days: %v", err)
	}
	if replaced.ID != created.ID {
		t.Fatalf("expected target ID %d to be reused, got %d", created.ID, replaced.ID)
	}
	if len(replaced.TargetDays) != 1 || !replaced.TargetDays[0].Date.Equal(replacementDate) {
		t.Fatalf("unexpected replacement target days: %#v", replaced.TargetDays)
	}

	_, err = ReplaceTargetDays(
		context.Background(),
		NewServices(sqliteDB),
		targetInput,
		[]time.Time{replacementDate, replacementDate},
	)
	if err == nil {
		t.Fatal("expected duplicate target days to violate the unique constraint")
	}

	var persistedDays []models.TargetDay
	if err := sqliteDB.Where("target_id = ?", created.ID).Find(&persistedDays).Error; err != nil {
		t.Fatalf("load target days after rollback: %v", err)
	}
	if len(persistedDays) != 1 || !persistedDays[0].Date.Equal(replacementDate) {
		t.Fatalf("expected previous target day to survive rollback, got %#v", persistedDays)
	}
}

func TestGetTargetsLast21DaysIncludesCurrentWeek(t *testing.T) {
	sqliteDB, err := gorm.Open(sqlite.Open(filepath.Join(t.TempDir(), "recent-targets.sqlite")), &gorm.Config{})
	if err != nil {
		t.Fatalf("open sqlite db: %v", err)
	}
	if err := sqliteDB.AutoMigrate(
		&models.User{},
		&models.Team{},
		&models.Target{},
		&models.TargetDay{},
	); err != nil {
		t.Fatalf("automigrate: %v", err)
	}

	user := models.User{UserID: "recent-user", Email: "recent@example.com", Username: "recent"}
	team := models.Team{Name: "Recent Team", Slug: "recent-team"}
	if err := sqliteDB.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}
	if err := sqliteDB.Create(&team).Error; err != nil {
		t.Fatalf("create team: %v", err)
	}

	now := time.Date(2026, time.September, 4, 12, 0, 0, 0, util.AppLocation())
	target := models.Target{
		TimeStart: util.TimeToWeekStart(now),
		UserID:    user.ID,
		TeamID:    team.ID,
	}
	if err := sqliteDB.Create(&target).Error; err != nil {
		t.Fatalf("create current target: %v", err)
	}

	targets, err := GetTargetsLast21DaysByUserTeam(
		context.Background(),
		NewServices(sqliteDB),
		user.ID,
		team.ID,
		now,
	)
	if err != nil {
		t.Fatalf("get recent targets: %v", err)
	}
	if len(targets) != 1 || targets[0].ID != target.ID {
		t.Fatalf("expected current-week target %d, got %#v", target.ID, targets)
	}
}

func TestAutoMigrateAllModelsRenamesLegacyTargetsTableAndIdentColumn(t *testing.T) {
	sqliteDB, err := gorm.Open(sqlite.Open(filepath.Join(t.TempDir(), "legacy-targets.sqlite")), &gorm.Config{})
	if err != nil {
		t.Fatalf("open sqlite db: %v", err)
	}

	if err := sqliteDB.Exec(`
		CREATE TABLE user_weekly_targets (
			id integer primary key autoincrement,
			created_at datetime,
			updated_at datetime,
			deleted_at datetime,
			time_start datetime NOT NULL,
			user_id integer NOT NULL,
			team_id integer NOT NULL,
			target_count integer NOT NULL
		)
	`).Error; err != nil {
		t.Fatalf("create legacy targets table: %v", err)
	}
	if err := sqliteDB.Exec(`
		CREATE TABLE idents (
			id integer primary key autoincrement,
			created_at datetime,
			updated_at datetime,
			deleted_at datetime,
			time datetime,
			user_text text,
			image_s3_key text,
			user_weekly_target_id integer
		)
	`).Error; err != nil {
		t.Fatalf("create legacy idents table: %v", err)
	}
	if err := sqliteDB.Exec(`
		INSERT INTO user_weekly_targets (time_start, user_id, team_id, target_count)
		VALUES (?, ?, ?, ?)
	`, time.Date(2026, 7, 6, 0, 0, 0, 0, time.UTC), 12, 34, 5).Error; err != nil {
		t.Fatalf("insert legacy target: %v", err)
	}
	if err := sqliteDB.Exec(`
		INSERT INTO idents (time, user_text, user_weekly_target_id)
		VALUES (?, ?, ?)
	`, time.Date(2026, 7, 8, 12, 0, 0, 0, time.UTC), "legacy ident", 1).Error; err != nil {
		t.Fatalf("insert legacy ident: %v", err)
	}

	AutoMigrateAllModels(sqliteDB)

	if sqliteDB.Migrator().HasTable("user_weekly_targets") {
		t.Fatal("expected legacy user_weekly_targets table to be renamed")
	}
	if !sqliteDB.Migrator().HasTable(&models.Target{}) {
		t.Fatal("expected targets table to exist")
	}
	if hasTableColumn(sqliteDB, "idents", "user_weekly_target_id") {
		t.Fatal("expected legacy idents.user_weekly_target_id column to be renamed")
	}
	if !hasTableColumn(sqliteDB, "idents", "target_id") {
		t.Fatal("expected idents.target_id column to exist")
	}

	var target models.Target
	if err := sqliteDB.First(&target, 1).Error; err != nil {
		t.Fatalf("load migrated target: %v", err)
	}
	var rawTargetCount uint
	if err := sqliteDB.Raw("SELECT target_count FROM targets WHERE id = ?", 1).Scan(&rawTargetCount).Error; err != nil {
		t.Fatalf("load raw migrated target count: %v", err)
	}
	if target.LegacyTargetCount != 5 || rawTargetCount != 5 {
		t.Fatalf("expected legacy target count 5, got %d via gorm and %d via raw SQL", target.LegacyTargetCount, rawTargetCount)
	}

	var ident models.Ident
	if err := sqliteDB.First(&ident, 1).Error; err != nil {
		t.Fatalf("load migrated ident: %v", err)
	}
	if ident.TargetID != target.ID {
		t.Fatalf("expected ident target id %d, got %d", target.ID, ident.TargetID)
	}
}

func TestAutoMigrateAllModelsRenamesLegacyNicknameColumn(t *testing.T) {
	sqliteDB, err := gorm.Open(sqlite.Open(filepath.Join(t.TempDir(), "legacy-users.sqlite")), &gorm.Config{})
	if err != nil {
		t.Fatalf("open sqlite db: %v", err)
	}

	if err := sqliteDB.Exec(`
		CREATE TABLE users (
			id integer primary key autoincrement,
			created_at datetime,
			updated_at datetime,
			deleted_at datetime,
			user_id text,
			email text,
			auth_provider text,
			password_hash text,
			full_name text,
			username text,
			avatar_s3_key text
		)
	`).Error; err != nil {
		t.Fatalf("create legacy users table: %v", err)
	}
	if err := sqliteDB.Exec(`
		INSERT INTO users (user_id, email, auth_provider, full_name, username)
		VALUES (?, ?, ?, ?, ?)
	`, "legacy-user", "legacy@example.com", "password", "Legacy Nick", "legacy").Error; err != nil {
		t.Fatalf("insert legacy user: %v", err)
	}

	AutoMigrateAllModels(sqliteDB)

	if sqliteDB.Migrator().HasColumn("users", "full_name") {
		t.Fatal("expected legacy full_name column to be renamed")
	}
	if !sqliteDB.Migrator().HasColumn("users", "nickname") {
		t.Fatal("expected nickname column to exist")
	}

	var user models.User
	if err := sqliteDB.Where("user_id = ?", "legacy-user").First(&user).Error; err != nil {
		t.Fatalf("load migrated user: %v", err)
	}
	if user.Nickname != "Legacy Nick" {
		t.Fatalf("expected nickname %q, got %q", "Legacy Nick", user.Nickname)
	}
}

func TestUnplannedIdentPreservesExistingTargetAndRollsBack(t *testing.T) {
	database, err := gorm.Open(sqlite.Open(filepath.Join(t.TempDir(), "unplanned.sqlite")), GormConfig())
	if err != nil {
		t.Fatal(err)
	}
	AutoMigrateAllModels(database)
	services := NewServices(database)
	user := models.User{UserID: "unplanned", Email: "unplanned@example.com", Username: "unplanned"}
	team := models.Team{Slug: "unplanned", Name: "Unplanned"}
	if err := database.Create(&user).Error; err != nil {
		t.Fatal(err)
	}
	if err := database.Create(&team).Error; err != nil {
		t.Fatal(err)
	}
	day, _ := util.ParseDateInAppLocation("2026-09-08")
	target, err := ReplaceTargetDays(context.Background(), services, models.Target{TimeStart: day, UserID: user.ID, TeamID: team.ID}, []time.Time{day})
	if err != nil {
		t.Fatal(err)
	}
	ident, err := CreateIdentWithUnplannedTarget(context.Background(), services, models.Ident{Time: day}, user.ID, team.ID)
	if err != nil {
		t.Fatal(err)
	}
	if ident.TargetID != target.ID {
		t.Fatal("existing target not reused")
	}
	var days int64
	if err := database.Model(&models.TargetDay{}).Where("target_id = ?", target.ID).Count(&days).Error; err != nil {
		t.Fatal(err)
	}
	if days != 1 {
		t.Fatal("existing planned days were changed")
	}
	if err := database.Exec("CREATE TRIGGER reject_ident BEFORE INSERT ON idents BEGIN SELECT RAISE(ABORT, 'test failure'); END").Error; err != nil {
		t.Fatal(err)
	}
	_, err = CreateIdentWithUnplannedTarget(context.Background(), services, models.Ident{Time: day.AddDate(0, 0, 7)}, user.ID, team.ID)
	if err == nil {
		t.Fatal("expected ident insert failure")
	}
	var targets int64
	if err := database.Model(&models.Target{}).Count(&targets).Error; err != nil {
		t.Fatal(err)
	}
	if targets != 1 {
		t.Fatal("failed ident left an empty target behind")
	}
}
