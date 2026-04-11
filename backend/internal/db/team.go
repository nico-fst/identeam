package db

import (
	"context"
	"errors"
	"identeam/internal/apns"
	"identeam/models"
	"log"
	"strings"

	"gorm.io/gorm"
)

const defaultTeamNotificationTemplate = "{{name}} hat ein neues Ident erstellt."

func stringPtr(s string) *string {
	return &s
}

func EnsureDefaultTeams(ctx context.Context, db *gorm.DB) error {
	defaultTeams := []models.Team{
		{
			Name:                 "Die Kanten",
			Slug:                 "die-kanten",
			Details:              "Hier sind Kanten drin",
			NotificationTemplate: stringPtr("OMG {{name}} ist mies am Gym hitten 🔥"),
		},
		{
			Name:                 "Wir4",
			Slug:                 "wir4",
			Details:              "Hier sind wir vier drin",
			NotificationTemplate: stringPtr("WOW {{name}} hat einen neuen Ident erstellt"),
		},
	}

	for _, team := range defaultTeams {
		var existing models.Team

		err := db.Where("slug = ?", team.Slug).First(&existing).Error
		if err == nil {
			continue
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}

		if _, err := CreateTeam(ctx, db, team); err != nil {
			return err
		}
	}

	return nil
}

func CreateTeam(ctx context.Context, db *gorm.DB, team models.Team) (*models.Team, error) {
	err := gorm.G[models.Team](db).
		Create(ctx, &team)
	if err != nil {
		log.Printf("ERROR creating team %v in DB: %v", team, err)
		return nil, err
	}

	log.Printf("Created team with slug %v in DB", team.Slug)
	return &team, nil
}

func AddUserToTeam(ctx context.Context, db *gorm.DB, userID string, teamSlug string) (*models.Team, error) {
	user, err := GetUserById(ctx, db, userID)
	if err != nil {
		return &models.Team{}, err
	}

	var team models.Team
	if err := db.Where("slug = ?", teamSlug).First(&team).Error; err != nil {
		return &models.Team{}, err
	}

	err = db.Model(&user).
		Association("Teams").
		Append(&team)
	if err != nil {
		return &models.Team{}, err
	}

	return &team, nil
}

func RemoveUserFromTeam(ctx context.Context, db *gorm.DB, userID string, teamSlug string) (*models.Team, error) {
	user, err := GetUserById(ctx, db, userID)
	if err != nil {
		return &models.Team{}, err
	}

	var team models.Team
	if err := db.Where("slug = ?", teamSlug).First(&team).Error; err != nil {
		return &models.Team{}, err
	}

	// GORM does not throw error when association does not exist
	err = db.Model(&user).
		Association("Teams").
		Delete(&team)
	if err != nil {
		return &models.Team{}, err
	}

	return &team, nil
}

func GetTeamBySlug(ctx context.Context, db *gorm.DB, slug string) (*models.Team, error) {
	var team models.Team
	err := db.Model(&models.Team{}).
		Preload("Users").
		Preload("Users.DeviceTokens").
		Where("slug = ?", strings.ToLower(slug)).
		First(&team).Error
	if err != nil {
		log.Printf("ERROR looking up team with slug %v", slug)
		return nil, err
	}

	return &team, nil
}

func GetTeamMembers(ctx context.Context, db *gorm.DB, userID string, teamSlug string) ([]*models.User, error) {
	var team models.Team
	if err := db.
		Preload("Users", "user_id <> ?", userID).
		Preload("Users.DeviceTokens").
		Where("slug = ? ", teamSlug). // not userID himself
		First(&team).Error; err != nil {
		return []*models.User{}, err
	}

	return team.Users, nil
}

func NotifyTeamMembers(ctx context.Context, db *gorm.DB, provider *apns.Provider, user models.User, slug string, subtitle string) ([]models.User, error) {
	team, err := GetTeamBySlug(ctx, db, slug)
	if err != nil {
		return nil, err
	}

	members := DerefUsers(team.Users)
	notificationTemplate := defaultTeamNotificationTemplate
	if team.NotificationTemplate != nil {
		notificationTemplate = *team.NotificationTemplate
	}

	notificationBody := strings.ReplaceAll(notificationTemplate, "{{name}}", user.FullName)

	notification := models.NotificationPayload{
		APS: models.APS{
			Alert: models.Alert{
				Title: "Neuer Ident",
				Body:  notificationBody,
			},
		},
	}

	if subtitle != "" {
		notification.APS.Alert.Subtitle = subtitle
	}

	err = provider.NotifyUsers(members, notification)
	if err != nil {
		return nil, err
	}

	return members, nil
}
