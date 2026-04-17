package models_test

import (
	"context"
	"strings"
	"testing"

	dbpkg "identeam/internal/db"
	"identeam/models"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func stringPtr(s string) *string {
	return &s
}

func openTestDB(t *testing.T) *gorm.DB {
	t.Helper()

	db, err := gorm.Open(sqlite.Open("file::memory:?cache=shared"), &gorm.Config{})
	if err != nil {
		t.Fatalf("failed to open test database: %v", err)
	}

	if err := db.AutoMigrate(&models.Team{}); err != nil {
		t.Fatalf("failed to migrate team model: %v", err)
	}

	return db
}

func TestTeamBeforeSaveRejectsNotificationTemplateWithoutNamePlaceholder(t *testing.T) {
	db := openTestDB(t)
	team := models.Team{
		Name:                 "Die Kanten",
		Slug:                 "Die-Kanten",
		NotificationTemplate: stringPtr("OMG Greta ist mies am Gym hitten"),
	}

	err := db.Create(&team).Error
	if err == nil {
		t.Fatal("expected validation error for notification template without {{name}}")
	}

	if !strings.Contains(err.Error(), "{{name}}") {
		t.Fatalf("expected error to mention {{name}}, got %v", err)
	}
}

func TestTeamBeforeSaveRejectsNotificationTemplateWithDuplicateNamePlaceholder(t *testing.T) {
	db := openTestDB(t)
	team := models.Team{
		Name:                 "Die Kanten",
		Slug:                 "Die-Kanten",
		NotificationTemplate: stringPtr("{{name}} und nochmal {{name}} liefern ab"),
	}

	err := db.Create(&team).Error
	if err == nil {
		t.Fatal("expected validation error for notification template with duplicate {{name}}")
	}

	if !strings.Contains(err.Error(), "exactly once") {
		t.Fatalf("expected exact-once validation error, got %v", err)
	}
}

func TestTeamBeforeSaveAllowsNotificationTemplateWithNamePlaceholder(t *testing.T) {
	db := openTestDB(t)
	team := models.Team{
		Name:                 "Die Kanten",
		Slug:                 "Die-Kanten",
		NotificationTemplate: stringPtr("OMG {{name}} ist mies am Gym hitten"),
	}

	if err := db.Create(&team).Error; err != nil {
		t.Fatalf("expected valid template to be saved, got %v", err)
	}

	if team.Slug != "die-kanten" {
		t.Fatalf("expected slug to be normalized, got %q", team.Slug)
	}
}

func TestGetTeamBySlugPreloadsUsersDeviceTokens(t *testing.T) {
	db, err := gorm.Open(sqlite.Open("file::memory:?cache=shared"), &gorm.Config{})
	if err != nil {
		t.Fatalf("failed to open test database: %v", err)
	}

	if err := db.AutoMigrate(&models.User{}, &models.DeviceToken{}, &models.Team{}); err != nil {
		t.Fatalf("failed to migrate models: %v", err)
	}

	user := models.User{
		UserID:   "user-1",
		Email:    "user1@example.com",
		FullName: "User One",
		Username: "userone",
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	token := models.DeviceToken{
		Token:    "device-token-123",
		Platform: "ios",
		UserID:   user.ID,
	}
	if err := db.Create(&token).Error; err != nil {
		t.Fatalf("create device token: %v", err)
	}

	team := models.Team{
		Name: "Push Team",
		Slug: "push-team",
	}
	if err := db.Create(&team).Error; err != nil {
		t.Fatalf("create team: %v", err)
	}

	if err := db.Model(&user).Association("Teams").Append(&team); err != nil {
		t.Fatalf("associate user with team: %v", err)
	}

	loadedTeam, err := dbpkg.GetTeamBySlug(context.Background(), db, team.Slug)
	if err != nil {
		t.Fatalf("GetTeamBySlug returned error: %v", err)
	}

	if len(loadedTeam.Users) != 1 {
		t.Fatalf("expected 1 user, got %d", len(loadedTeam.Users))
	}

	if len(loadedTeam.Users[0].DeviceTokens) != 1 {
		t.Fatalf("expected 1 preloaded device token, got %d", len(loadedTeam.Users[0].DeviceTokens))
	}

	if loadedTeam.Users[0].DeviceTokens[0].Token != token.Token {
		t.Fatalf("expected token %q, got %q", token.Token, loadedTeam.Users[0].DeviceTokens[0].Token)
	}
}
