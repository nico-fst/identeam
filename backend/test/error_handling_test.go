package test

import (
	"context"
	"errors"
	"path/filepath"
	"testing"

	"identeam/internal/db"
	"identeam/models"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func TestAutoMigrateAllModelsReturnsDatabaseError(t *testing.T) {
	database, err := gorm.Open(sqlite.Open(filepath.Join(t.TempDir(), "migration.sqlite")), db.GormConfig())
	if err != nil {
		t.Fatal(err)
	}
	sqlDB, err := database.DB()
	if err != nil {
		t.Fatal(err)
	}
	if err := sqlDB.Close(); err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrateAllModels(database); err == nil {
		t.Fatal("expected migration failure from a closed database")
	}
}

func TestCommentNotificationReturnsMemberLookupError(t *testing.T) {
	database, err := gorm.Open(sqlite.Open(filepath.Join(t.TempDir(), "notification.sqlite")), db.GormConfig())
	if err != nil {
		t.Fatal(err)
	}
	sqlDB, err := database.DB()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := sqlDB.Close(); err != nil {
			t.Error(err)
		}
	})
	if err := db.AutoMigrateAllModels(database); err != nil {
		t.Fatal(err)
	}
	user := models.User{UserID: "author", Email: "author@example.com", Username: "author"}
	team := models.Team{Slug: "team", Name: "Team"}
	if err := database.Create(&user).Error; err != nil {
		t.Fatal(err)
	}
	if err := database.Create(&team).Error; err != nil {
		t.Fatal(err)
	}
	target := models.Target{UserID: user.ID, TeamID: team.ID}
	if err := database.Create(&target).Error; err != nil {
		t.Fatal(err)
	}
	ident := models.Ident{TargetID: target.ID}
	if err := database.Create(&ident).Error; err != nil {
		t.Fatal(err)
	}
	lookupError := errors.New("member lookup failed")
	failed := false
	if err := database.Callback().Query().Before("gorm:query").Register("test:fail_member_lookup", func(tx *gorm.DB) {
		if tx.Statement.Schema != nil && tx.Statement.Schema.Name == "Team" && !failed {
			if _, ok := tx.Statement.Preloads["Users"]; ok {
				failed = true
				_ = tx.AddError(lookupError)
			}
		}
	}); err != nil {
		t.Fatal(err)
	}
	members, err := db.NotifyTeamMembersAboutNewComment(context.Background(), db.NewServices(database), &models.Comment{IdentID: ident.ID, User: user}, user.ID)
	if !errors.Is(err, lookupError) || members != nil {
		t.Fatalf("got members %v, error %v; want member lookup error", members, err)
	}
}
